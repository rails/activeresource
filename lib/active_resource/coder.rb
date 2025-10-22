# frozen_string_literal: true

module ActiveResource
  # Integrates with Active Record's
  # {serialize}[link:https://api.rubyonrails.org/classes/ActiveRecord/AttributeMethods/Serialization/ClassMethods.html#method-i-serialize]
  # method as the <tt>:coder</tt> option.
  #
  # Encodes Active Resource instances into a value to be stored in the
  # database. Decodes values read from the database into Active Resource
  # instances.
  #
  #   class Person < ActiveResource::Base
  #     schema do
  #       attribute :name, :string
  #     end
  #   end
  #
  #   class User < ActiveRecord::Base
  #     serialize :person, coder: Person
  #   end
  #
  #   user = User.new
  #   user.person = Person.new name: "Matz"
  #   user.person.name # => "Matz"
  #
  # Values are loaded as persisted when decoded from data containing a
  # primary key value, and new records when missing a primary key value:
  #
  #   user.person = Person.new
  #   user.person.persisted? # => true
  #
  #   user.person = Person.find(1)
  #   user.person.persisted? # => true
  #
  # By default, <tt>#dump</tt> serializes the instance to a string value by
  # calling Base#encode:
  #
  #   user.person_before_type_cast # => "{\"name\":\"Matz\"}"
  #
  # To customize serialization, pass the method name or a block that accepts the
  # instance as the second argument:
  #
  #   person = Person.new name: "Matz"
  #
  #   coder = ActiveResource::Coder.new(Person, :serializable_hash)
  #   coder.dump(person) # => { "name" => "Matz" }
  #
  #   coder = ActiveResource::Coder.new(Person) { |person| person.serializable_hash }
  #   coder.dump(person) # => { "name" => "Matz" }
  #
  # === Collections
  #
  # To encode ActiveResource::Collection instances, construct an instance with +collection:
  # true+.
  #
  #   class Team < ActiveRecord::Base
  #     serialize :people, coder: ActiveResource::Coder.new(Person, collection: true)
  #   end
  #
  #   team = Team.new
  #   team.people = Person.all
  #   team.people.map(&:attributes) # => [{ "id" => 1, "name" => "Matz" }]
  #
  # By default, <tt>#dump</tt> serializes the instance to a string value by
  # calling Collection#encode:
  #
  #   team.people_before_type_cast # => "[{\"id\":1,\"name\":\"Matz\"}]"
  #
  # To customize serialization, pass a block that accepts the collection as the second argument:
  #
  #   people = Person.all
  #
  #   coder = ActiveResource::Coder.new(Person) { |collection| collection.original_parsed }
  #   coder.dump(people) # => [{ "id" => 1, "name" => "Matz" }]
  class Coder
    attr_accessor :resource_class, :encoder, :collection

    # ==== Arguments
    # * <tt>resource_class</tt> Active Resource class that to be coded
    # * <tt>encoder_method</tt> the method to invoke on the instance to encode
    # it. Defaults to ActiveResource::Base#encode.
    #
    # ==== Options
    #
    # * <tt>:collection</tt> - Whether or not the values represent an
    # ActiveResource::Collection Defaults to false.
    def initialize(resource_class, encoder_method = :encode, collection: false, &block)
      @resource_class = resource_class
      @encoder = block || encoder_method
      @collection = collection
    end

    # Serializes a resource value to a value that will be stored in the database.
    # Returns nil when passed nil
    def dump(value)
      return if value.nil?

      expected_class = collection ? resource_class.collection_parser : resource_class
      raise ArgumentError.new("expected value to be #{expected_class}, but was #{value.class}") unless value.is_a?(expected_class)

      value.yield_self(&encoder)
    end

    # Deserializes a value from the database to a resource instance.
    # Returns nil when passed nil
    def load(value)
      return if value.nil?
      value = resource_class.format.decode(value) if value.is_a?(String)

      if collection
        raise ArgumentError.new("expected value to be Hash or Array, but was #{value.class}") unless value.is_a?(Hash) || value.is_a?(Array)
        resource_class.instantiate_collection(value)
      else
        raise ArgumentError.new("expected value to be Hash, but was #{value.class}") unless value.is_a?(Hash)
        value = Formats.remove_root(value) if value.keys.first.to_s == resource_class.element_name
        resource_class.new(value, value[resource_class.primary_key])
      end
    end
  end
end
