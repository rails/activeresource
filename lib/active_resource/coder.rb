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
  #   class User < ActiveRecord::Base
  #     serialize :person, coder: ActiveResource::Coder.new(Person)
  #   end
  #
  #   class Person < ActiveResource::Base
  #     schema do
  #       attribute :name, :string
  #     end
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
  # To customize serialization, pass the method name or a block as the second
  # argument:
  #
  #   person = Person.new name: "Matz"
  #
  #   coder = ActiveResource::Coder.new(Person, :serializable_hash)
  #   coder.dump(person) # => { "name" => "Matz" }
  #
  #   coder = ActiveResource::Coder.new(Person) { |person| person.serializable_hash }
  #   coder.dump(person) # => { "name" => "Matz" }
  class Coder
    attr_accessor :resource_class, :encoder

    def initialize(resource_class, encoder_method = :encode, &block)
      @resource_class = resource_class
      @encoder = block || encoder_method
    end

    # Serializes a resource value to a value that will be stored in the database.
    # Returns nil when passed nil
    def dump(value)
      return if value.nil?
      raise ArgumentError.new("expected value to be #{resource_class}, but was #{value.class}") unless value.is_a?(resource_class)

      value.yield_self(&encoder)
    end

    # Deserializes a value from the database to a resource instance.
    # Returns nil when passed nil
    def load(value)
      return if value.nil?
      value = resource_class.format.decode(value) if value.is_a?(String)
      raise ArgumentError.new("expected value to be Hash, but was #{value.class}") unless value.is_a?(Hash)
      resource_class.new(value, value[resource_class.primary_key])
    end
  end
end
