# frozen_string_literal: true

module ActiveResource
  # Compatibilitiy with Active Record's
  # {serialize}[link:https://api.rubyonrails.org/classes/ActiveRecord/AttributeMethods/Serialization/ClassMethods.html#method-i-serialize]
  # method as the <tt>:coder</tt> option.
  #
  # === Writing to String columns
  #
  # Encodes Active Resource instances into a string to be stored in the
  # database. Decodes strings read from the database into Active Resource
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
  #
  # Writing string values incorporates the Base.format:
  #
  #   Person.format = :json
  #
  #   user.person = Person.new name: "Matz"
  #   user.person_before_type_cast # => "{\"name\":\"Matz\"}"
  #
  #   Person.format = :xml
  #
  #   user.person = Person.new name: "Matz"
  #   user.person_before_type_cast # => "<?xml version=\"1.0\" encoding=\"UTF-8\"?><person><name>Matz</name></person>"
  #
  # Instances are loaded as persisted when decoded from data containing a
  # primary key value, and new records when missing a primary key value:
  #
  #   user.person = Person.new
  #   user.person.persisted? # => false
  #
  #   user.person = Person.find(1)
  #   user.person.persisted? # => true
  #
  # === Writing to JSON and JSONB columns
  #
  #   class User < ActiveRecord::Base
  #     serialize :person, coder: ActiveResource::Coder.new(Person, :serializable_hash)
  #   end
  #
  #   class Person < ActiveResource::Base
  #     schema do
  #       attribute :name, :string
  #     end
  #   end
  #
  #   class User < ActiveRecord::Base
  #     serialize :person, coder: ActiveResource::Coder.new(Person, :serializable_hash)
  #   end
  #
  #   user = User.new
  #   user.person = Person.new name: "Matz"
  #   user.person.name # => "Matz"
  #
  #   user.person_before_type_cast # => {"name"=>"Matz"}
  module Serialization
    extend ActiveSupport::Concern

    included do
      class_attribute :coder, instance_accessor: false, instance_predicate: false
    end

    module ClassMethods
      delegate :dump, :load, to: :coder

      def inherited(subclass) # :nodoc:
        super
        subclass.coder = Coder.new(subclass)
      end
    end
  end
end
