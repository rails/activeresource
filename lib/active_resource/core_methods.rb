require 'active_support/core_ext/module/attribute_accessors'

module ActiveResource
  module CoreMethods # :nodoc:
    extend ActiveSupport::Concern

    module ClassMethods

      # Creates a schema for this resource - setting the attributes that are
      # known prior to fetching an instance from the remote system.
      #
      # The schema helps define the set of <tt>known_attributes</tt> of the
      # current resource.
      #
      # There is no need to specify a schema for your Active Resource. If
      # you do not, the <tt>known_attributes</tt> will be guessed from the
      # instance attributes returned when an instance is fetched from the
      # remote system.
      #
      # example:
      #   class Person < ActiveResource::Base
      #     schema do
      #       # define each attribute separately
      #       attribute 'name', :string
      #
      #       # or use the convenience methods and pass >=1 attribute names
      #       string  'eye_color', 'hair_color'
      #       integer 'age'
      #       float   'height', 'weight'
      #
      #       # unsupported types should be left as strings
      #       # overload the accessor methods if you need to convert them
      #       attribute 'created_at', 'string'
      #     end
      #   end
      #
      #   p = Person.new
      #   p.respond_to? :name   # => true
      #   p.respond_to? :age    # => true
      #   p.name                # => nil
      #   p.age                 # => nil
      #
      #   j = Person.find_by_name('John')
      #   <person><name>John</name><age>34</age><num_children>3</num_children></person>
      #   j.respond_to? :name   # => true
      #   j.respond_to? :age    # => true
      #   j.name                # => 'John'
      #   j.age                 # => '34'  # note this is a string!
      #   j.num_children        # => '3'  # note this is a string!
      #
      #   p.num_children        # => NoMethodError
      #
      # Attribute-types must be one of: <tt>string, integer, float</tt>
      #
      # Note: at present the attribute-type doesn't do anything, but stay
      # tuned...
      # Shortly it will also *cast* the value of the returned attribute.
      # ie:
      # j.age                 # => 34   # cast to an integer
      # j.weight              # => '65' # still a string!
      #
      def schema(&block)
        if block_given?
          schema_definition = Schema.new
          schema_definition.instance_eval(&block)

          # skip out if we didn't define anything
          return unless schema_definition.attrs.present?

          @schema ||= {}.with_indifferent_access
          @known_attributes ||= []

          schema_definition.attrs.each do |k,v|
            @schema[k] = v
            @known_attributes << k
          end

          schema
        else
          @schema ||= nil
        end
      end

      # Alternative, direct way to specify a <tt>schema</tt> for this
      # Resource. <tt>schema</tt> is more flexible, but this is quick
      # for a very simple schema.
      #
      # Pass the schema as a hash with the keys being the attribute-names
      # and the value being one of the accepted attribute types (as defined
      # in <tt>schema</tt>)
      #
      # example:
      #
      #   class Person < ActiveResource::Base
      #     schema = {'name' => :string, 'age' => :integer }
      #   end
      #
      # The keys/values can be strings or symbols. They will be converted to
      # strings.
      #
      def schema=(the_schema)
        unless the_schema.present?
          # purposefully nulling out the schema
          @schema = nil
          @known_attributes = []
          return
        end

        raise ArgumentError, "Expected a hash" unless the_schema.kind_of? Hash

        schema do
          the_schema.each {|k,v| attribute(k,v) }
        end
      end


      # Returns the list of known attributes for this resource, gathered
      # from the provided <tt>schema</tt>
      # Attributes that are known will cause your resource to return 'true'
      # when <tt>respond_to?</tt> is called on them. A known attribute will
      # return nil if not set (rather than <tt>MethodNotFound</tt>); thus
      # known attributes can be used with <tt>validates_presence_of</tt>
      # without a getter-method.
      def known_attributes
        @known_attributes ||= []
      end

      attr_writer :primary_key

      def primary_key
        if defined?(@primary_key)
          @primary_key
        elsif superclass != Object && superclass.primary_key
          primary_key = superclass.primary_key
          return primary_key if primary_key.is_a?(Symbol)
          primary_key.dup.freeze
        else
          'id'
        end
      end



      alias_method :set_primary_key, :primary_key=  #:nodoc:

      # Builds a new, unsaved record using the default values from the remote server so
      # that it can be used with RESTful forms.
      #
      # ==== Options
      # * +attributes+ - A hash that overrides the default values from the server.
      #
      # Returns the new resource instance.
      #
      def build(attributes = {})
        attrs = self.format.decode(connection.get("#{new_element_path(attributes)}", headers).body)
        self.new(attrs)
      end

      private

      def instantiate_collection(collection, original_params = {}, prefix_options = {})
        collection_parser.new(collection).tap do |parser|
          parser.resource_class  = self
          parser.original_params = original_params
        end.collect! { |record| instantiate_record(record, prefix_options) }
      end

      def instantiate_record(record, prefix_options = {})
        new(record, true).tap do |resource|
          resource.prefix_options = prefix_options
        end
      end

    end


    # If no schema has been defined for the class (see
    # <tt>ActiveResource::schema=</tt>), the default automatic schema is
    # generated from the current instance's attributes
    def schema
      self.class.schema || self.attributes
    end

    # This is a list of known attributes for this resource. Either
    # gathered from the provided <tt>schema</tt>, or from the attributes
    # set on this instance after it has been fetched from the remote system.
    def known_attributes
      (self.class.known_attributes + self.attributes.keys.map(&:to_s)).uniq
    end

    # Returns a \clone of the resource that hasn't been assigned an +id+ yet and
    # is treated as a \new resource.
    #
    #   ryan = Person.find(1)
    #   not_ryan = ryan.clone
    #   not_ryan.new?  # => true
    #
    # Any active resource member attributes will NOT be cloned, though all other
    # attributes are. This is to prevent the conflict between any +prefix_options+
    # that refer to the original parent resource and the newly cloned parent
    # resource that does not exist.
    #
    #   ryan = Person.find(1)
    #   ryan.address = StreetAddress.find(1, :person_id => ryan.id)
    #   ryan.hash = {:not => "an ARes instance"}
    #
    #   not_ryan = ryan.clone
    #   not_ryan.new?            # => true
    #   not_ryan.address         # => NoMethodError
    #   not_ryan.hash            # => {:not => "an ARes instance"}
    def clone
      # Clone all attributes except the pk and any nested ARes
      cloned = Hash[attributes.reject {|k,v| k == self.class.primary_key || v.is_a?(ActiveResource::Base)}.map { |k, v| [k, v.clone] }]
      # Form the new resource - bypass initialize of resource with 'new' as that will call 'load' which
      # attempts to convert hashes into member objects and arrays into collections of objects. We want
      # the raw objects to be cloned so we bypass load by directly setting the attributes hash.
      resource = self.class.new({})
      resource.prefix_options = self.prefix_options
      resource.send :instance_variable_set, '@attributes', cloned
      resource
    end

    # Test for equality. Resource are equal if and only if +other+ is the same object or
    # is an instance of the same class, is not <tt>new?</tt>, and has the same +id+.
    #
    # ==== Examples
    #   ryan = Person.create(:name => 'Ryan')
    #   jamie = Person.create(:name => 'Jamie')
    #
    #   ryan == jamie
    #   # => false (Different name attribute and id)
    #
    #   ryan_again = Person.new(:name => 'Ryan')
    #   ryan == ryan_again
    #   # => false (ryan_again is new?)
    #
    #   ryans_clone = Person.create(:name => 'Ryan')
    #   ryan == ryans_clone
    #   # => false (Different id attributes)
    #
    #   ryans_twin = Person.find(ryan.id)
    #   ryan == ryans_twin
    #   # => true
    #
    def ==(other)
      other.equal?(self) || (other.instance_of?(self.class) && other.id == id && other.prefix_options == prefix_options)
    end

    # Tests for equality (delegates to ==).
    def eql?(other)
      self == other
    end

    # Delegates to id in order to allow two resources of the same type and \id to work with something like:
    #   [(a = Person.find 1), (b = Person.find 2)] & [(c = Person.find 1), (d = Person.find 4)] # => [a]
    def hash
      id.hash
    end

    # Duplicates the current resource without saving it.
    #
    # ==== Examples
    #   my_invoice = Invoice.create(:customer => 'That Company')
    #   next_invoice = my_invoice.dup
    #   next_invoice.new? # => true
    #
    #   next_invoice.save
    #   next_invoice == my_invoice # => false (different id attributes)
    #
    #   my_invoice.customer   # => That Company
    #   next_invoice.customer # => That Company
    def dup
      self.class.new.tap do |resource|
        resource.attributes     = @attributes
        resource.prefix_options = @prefix_options
      end
    end


    protected

    def connection(refresh = false)
      self.class.connection(refresh)
    end

    private

    # Tries to find a resource for a given collection name; if it fails, then the resource is created
    def find_or_create_resource_for_collection(name)
      return reflections[name.to_sym].klass if reflections.key?(name.to_sym)
      find_or_create_resource_for(ActiveSupport::Inflector.singularize(name.to_s))
    end

    # Tries to find a resource in a non empty list of nested modules
    # if it fails, then the resource is created
    def find_or_create_resource_in_modules(resource_name, module_names)
      receiver = Object
      namespaces = module_names[0, module_names.size-1].map do |module_name|
        receiver = receiver.const_get(module_name)
      end
      const_args = [resource_name, false]
      if namespace = namespaces.reverse.detect { |ns| ns.const_defined?(*const_args) }
        namespace.const_get(*const_args)
      else
        create_resource_for(resource_name)
      end
    end

    # Tries to find a resource for a given name; if it fails, then the resource is created
    def find_or_create_resource_for(name)
      return reflections[name.to_sym].klass if reflections.key?(name.to_sym)
      resource_name = name.to_s.camelize

      const_args = [resource_name, false]
      if self.class.const_defined?(*const_args)
        self.class.const_get(*const_args)
      else
        ancestors = self.class.name.to_s.split("::")
        if ancestors.size > 1
          find_or_create_resource_in_modules(resource_name, ancestors)
        else
          if Object.const_defined?(*const_args)
            Object.const_get(*const_args)
          else
            create_resource_for(resource_name)
          end
        end
      end
    end

    # Create and return a class definition for a resource inside the current resource
    def create_resource_for(resource_name)
      resource = self.class.const_set(resource_name, Class.new(ActiveResource::Base))
      resource.prefix = self.class.prefix
      resource.site   = self.class.site
      resource
    end

    def split_options(options = {})
      self.class.__send__(:split_options, options)
    end

  end
end
