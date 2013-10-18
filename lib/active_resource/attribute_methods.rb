module ActiveResource
  module AttributeMethods
    extend ActiveSupport::Concern

    # A method to manually load attributes from a \hash. Recursively loads collections of
    # resources. This method is called in +initialize+ and +create+ when a \hash of attributes
    # is provided.
    #
    # ==== Examples
    #   my_attrs = {:name => 'J&J Textiles', :industry => 'Cloth and textiles'}
    #   my_attrs = {:name => 'Marty', :colors => ["red", "green", "blue"]}
    #
    #   the_supplier = Supplier.find(:first)
    #   the_supplier.name # => 'J&M Textiles'
    #   the_supplier.load(my_attrs)
    #   the_supplier.name('J&J Textiles')
    #
    #   # These two calls are the same as Supplier.new(my_attrs)
    #   my_supplier = Supplier.new
    #   my_supplier.load(my_attrs)
    #
    #   # These three calls are the same as Supplier.create(my_attrs)
    #   your_supplier = Supplier.new
    #   your_supplier.load(my_attrs)
    #   your_supplier.save
    def load(attributes, remove_root = false, persisted = false)
      raise ArgumentError, "expected an attributes Hash, got #{attributes.inspect}" unless attributes.is_a?(Hash)
      @prefix_options, attributes = split_options(attributes)

      if attributes.keys.size == 1
        remove_root = self.class.element_name == attributes.keys.first.to_s
      end

      attributes = Formats.remove_root(attributes) if remove_root

      attributes.each do |key, value|
        @attributes[key.to_s] =
            case value
              when Array
                resource = nil
                value.map do |attrs|
                  if attrs.is_a?(Hash)
                    resource ||= find_or_create_resource_for_collection(key)
                    resource.new(attrs, persisted)
                  else
                    attrs.duplicable? ? attrs.dup : attrs
                  end
                end
              when Hash
                resource = find_or_create_resource_for(key)
                resource.new(value, persisted)
              else
                value.duplicable? ? value.dup : value
            end
      end
      self
    end

    def attribute(name)
      attributes[name]
    end

    # For checking <tt>respond_to?</tt> without searching the attributes (which is faster).
    alias_method :respond_to_without_attributes?, :respond_to?

    # A method to determine if an object responds to a message (e.g., a method call). In Active Resource, a Person object with a
    # +name+ attribute can answer <tt>true</tt> to <tt>my_person.respond_to?(:name)</tt>, <tt>my_person.respond_to?(:name=)</tt>, and
    # <tt>my_person.respond_to?(:name?)</tt>.
    def respond_to?(method, include_priv = false)
      method_name = method.to_s
      if attributes.nil?
        super
      elsif known_attributes.include?(method_name)
        true
      elsif method_name =~ /(?:=|\?)$/ && attributes.include?($`)
        true
      else
        # super must be called at the end of the method, because the inherited respond_to?
        # would return true for generated readers, even if the attribute wasn't present
        super
      end
    end

    protected
    def method_missing(method_symbol, *arguments) #:nodoc:
      method_name = method_symbol.to_s

      if method_name =~ /(=|\?)$/
        case $1
          when "="
            attributes[$`] = arguments.first
          when "?"
            attributes[$`]
        end
      else
        return attributes[method_name] if attributes.include?(method_name)
        # not set right now but we know about it
        return nil if known_attributes.include?(method_name)
        super
      end
    end






  end
end