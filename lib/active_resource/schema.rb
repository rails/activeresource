# frozen_string_literal: true

module ActiveResource # :nodoc:
  class Schema # :nodoc:
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Serialization

    # attributes can be known to be one of these types. They are easy to
    # cast to/from.
    KNOWN_ATTRIBUTE_TYPES = %w[ string text integer float decimal datetime timestamp time date binary boolean ]

    # An array of attribute definitions, representing the attributes that
    # have been defined.
    class_attribute :attrs, instance_accessor: false, instance_predicate: false # :nodoc:
    self.attrs = {}

    class_attribute :cast_values, instance_accessor: false, instance_predicate: false # :nodoc:
    self.cast_values = false

    attribute_method_suffix "?", parameters: false

    alias_method :attribute?, :send
    private :attribute?

    # The internals of an Active Resource Schema are very simple -
    # unlike an Active Record TableDefinition (on which it is based).
    # It provides a set of convenience methods for people to define their
    # schema using the syntax:
    #  schema do
    #    string :foo
    #    integer :bar
    #  end
    #
    #  The schema stores the name and type of each attribute. That is then
    #  read out by the schema method to populate the schema of the actual
    #  resource.

    class << self
      def inherited(subclass)
        super
        subclass.attrs = attrs.dup
      end

      # The internals of an Active Resource Schema are very simple -
      # unlike an Active Record TableDefinition (on which it is based).
      # It provides a set of convenience methods for people to define their
      # schema using the syntax:
      #  schema do
      #    string :foo
      #    integer :bar
      #  end
      #
      #  The schema stores the name and type of each attribute. That is then
      #  read out by the schema method to populate the schema of the actual
      #  resource.
      def attribute(name, type = nil, options = {})
        raise ArgumentError, "Unknown Attribute type: #{type.inspect} for key: #{name.inspect}" unless type.nil? || Schema::KNOWN_ATTRIBUTE_TYPES.include?(type.to_s)

        the_type = type&.to_s
        attrs[name.to_s] = the_type
        type = cast_values ? type&.to_sym : nil

        super(name, type, **options)
        self
      end

      # The following are the attribute types supported by Active Resource
      # migrations.
      KNOWN_ATTRIBUTE_TYPES.each do |attr_type|
        # def string(*args)
        #   options = args.extract_options!
        #   attr_names = args
        #
        #   attr_names.each { |name| attribute(name, 'string', options) }
        # end
        class_eval <<-EOV, __FILE__, __LINE__ + 1
          # frozen_string_literal: true
          def #{attr_type}(*args)
            options = args.extract_options!
            attr_names = args

            attr_names.each { |name| attribute(name, :#{attr_type}, **options) }
          end
        EOV
      end
    end
  end
end
