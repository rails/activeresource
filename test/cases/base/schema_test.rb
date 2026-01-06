# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/hash/conversions"
require "fixtures/person"
require "fixtures/street_address"

########################################################################
# Testing the schema of your Active Resource models
########################################################################
class SchemaTest < ActiveSupport::TestCase
  def setup
    setup_response # find me in abstract_unit
  end

  def teardown
    Person.cast_values = false
    Person.schema = nil # hack to stop test bleedthrough...
  end


  #####################################################
  # Passing in a schema directly and returning it
  ####

  test "schema on a new model should be empty" do
    assert Person.schema.blank?, "should have a blank class schema"
    assert Person.new.schema.blank?, "should have a blank instance schema"
  end

  test "schema should only accept a hash" do
    [ "blahblah", [ "one", "two" ],  [ :age, :name ], Person.new ].each do |bad_schema|
      assert_raises(ArgumentError, "should only accept a hash (or nil), but accepted: #{bad_schema.inspect}") do
        Person.schema = bad_schema
      end
    end
  end

  test "schema should accept a simple hash" do
    new_schema = { "age" => "integer", "name" => "string",
      "height" => "float", "bio" => "text",
      "weight" => "decimal", "photo" => "binary",
      "alive" => "boolean", "created_at" => "timestamp",
      "thetime" => "time", "thedate" => "date", "mydatetime" => "datetime" }

    assert_nothing_raised { Person.schema = new_schema }
    assert_equal new_schema, Person.schema
  end

  test "schema should accept a hash with simple values" do
    new_schema = { "age" => "integer", "name" => "string",
      "height" => "float", "bio" => "text",
      "weight" => "decimal", "photo" => "binary",
      "alive" => "boolean", "created_at" => "timestamp",
      "thetime" => "time", "thedate" => "date", "mydatetime" => "datetime" }

    assert_nothing_raised { Person.schema = new_schema }
    assert_equal new_schema, Person.schema
  end

  test "schema should accept all known attribute types as values" do
    ActiveResource::Schema::KNOWN_ATTRIBUTE_TYPES.each do |the_type|
      assert_nothing_raised { Person.schema = { "my_key" => the_type } }
    end
  end

  test "schema should not accept unknown values" do
    bad_values = [ :oogle, :blob, "thing" ]

    bad_values.each do |bad_value|
      assert_raises(ArgumentError, "should only accept a known attribute type, but accepted: #{bad_value.inspect}") do
        Person.schema = { "key" => bad_value }
      end
    end
  end

  test "schema should accept nil and remove the schema" do
    new_schema = { "age" => "integer", "name" => "string",
      "height" => "float", "bio" => "text",
      "weight" => "decimal", "photo" => "binary",
      "alive" => "boolean", "created_at" => "timestamp",
      "thetime" => "time", "thedate" => "date", "mydatetime" => "datetime" }

    assert_nothing_raised { Person.schema = new_schema }
    assert_equal new_schema, Person.schema # sanity check

    assert_nothing_raised { Person.schema = nil }
    assert_nil Person.schema, "should have nulled out the schema, but still had: #{Person.schema.inspect}"
  end

  test "schema should be with indifferent access" do
    new_schema = { "age" => "integer", "name" => "string",
      "height" => "float", "bio" => "text",
      "weight" => "decimal", "photo" => "binary",
      "alive" => "boolean", "created_at" => "timestamp",
      "thetime" => "time", "thedate" => "date", "mydatetime" => "datetime" }

    new_schema_syms = new_schema.keys

    assert_nothing_raised { Person.schema = new_schema }
    new_schema_syms.each do |col|
      assert Person.new.respond_to?(col.to_s), "should respond to the schema's string key, but failed on: #{col}"
      assert Person.new.respond_to?(col.to_sym), "should respond to the schema's symbol key, but failed on: #{col.to_sym}"
    end
  end

  test "schema on a fetched resource should return all the attributes of that model instance" do
    p = Person.find(1)
    s = p.schema

    assert s.present?, "should have found a non-empty schema!"

    p.attributes.each do |the_attr, val|
      assert s.has_key?(the_attr), "should have found attr: #{the_attr} in schema, but only had: #{s.inspect}"
    end
  end

  test "with two instances, default schema should match the attributes of the individual instances - even if they differ" do
    matz = Person.find(1)
    rick = Person.find(6)

    m_attrs = matz.attributes.keys.sort
    r_attrs = rick.attributes.keys.sort

    assert_not_equal m_attrs, r_attrs, "should have different attributes on each model"

    assert_not_equal matz.schema, rick.schema, "should have had different schemas too"
  end

  test "defining a schema should return it when asked" do
    assert Person.schema.blank?, "should have a blank class schema"
    new_schema = { "age" => "integer", "name" => "string",
      "height" => "float", "bio" => "text",
      "weight" => "decimal", "photo" => "binary",
      "alive" => "boolean", "created_at" => "timestamp",
      "thetime" => "time", "thedate" => "date", "mydatetime" => "datetime" }

    assert_nothing_raised {
      Person.schema = new_schema
      assert_equal new_schema, Person.schema, "should have saved the schema on the class"
      assert_equal new_schema, Person.new.schema, "should have made the schema available to every instance"
    }
  end

  test "defining a schema, then fetching a model should still match the defined schema" do
    # sanity checks
    assert Person.schema.blank?, "should have a blank class schema"
    new_schema = { "age" => "integer", "name" => "string",
      "height" => "float", "bio" => "text",
      "weight" => "decimal", "photo" => "binary",
      "alive" => "boolean", "created_at" => "timestamp",
      "thetime" => "time", "thedate" => "date", "mydatetime" => "datetime" }

    matz = Person.find(1)
    assert_not matz.schema.blank?, "should have some sort of schema on an instance variable"
    assert_not_equal new_schema, matz.schema, "should not have the class-level schema until it's been added to the class!"

    assert_nothing_raised {
      Person.schema = new_schema
      assert_equal new_schema, matz.schema, "class-level schema should override instance-level schema"
    }
  end

  test "classes can alias attributes for a schema they inherit from their ancestors" do
    base = Class.new(ActiveResource::Base) do
      schema { attribute :base_attribute }
    end
    person = Class.new(base) do
      schema { alias_attribute :aliased_attribute, :base_attribute }
    end

    resource = person.new

    assert_changes -> { resource.base_attribute }, to: "value" do
      resource.aliased_attribute = "value"
    end
    assert_equal [ "base_attribute" ], resource.attribute_names
    assert_equal "value", resource.serializable_hash["base_attribute"]
    assert_not_includes resource.serializable_hash, "aliased_attribute"
  end

  test "classes can extend the schema they inherit from their ancestors" do
    base = Class.new(ActiveResource::Base) do
      schema { attribute :created_at, :datetime }
    end
    cast_values = Class.new(base) do
      schema(cast_values: true) { attribute :accepted_terms_and_conditions, :boolean }
    end
    uncast_values = Class.new(base) do
      schema(cast_values: false) { attribute :line1, :string }
    end

    cast_resource = cast_values.new
    uncast_resource = uncast_values.new

    assert_changes -> { cast_resource.accepted_terms_and_conditions }, to: true do
      cast_resource.accepted_terms_and_conditions = "1"
    end
    assert_changes -> { cast_resource.created_at.try(:to_date) }, from: nil, to: Date.new(2025, 1, 1) do
      cast_resource.created_at = "2025-01-01"
    end
    assert_changes -> { uncast_resource.line1 }, to: 123 do
      uncast_resource.line1 = 123
    end
    assert_changes -> { uncast_resource.created_at }, from: nil, to: "2025-01-01" do
      uncast_resource.created_at = "2025-01-01"
    end
  end

  #####################################################
  # Using the schema syntax
  ####

  test "should be able to use schema" do
    assert_respond_to Person, :schema, "should at least respond to the schema method"

    assert_nothing_raised do
      Person.schema { }
    end
  end

  test "schema definition should store and return attribute set" do
    assert_nothing_raised do
      s = nil
      Person.schema do
        s = self
        attribute :foo, :string
      end
      assert_respond_to s, :attrs, "should return attributes in theory"
      assert_equal({ "foo" => "string" }, s.attrs, "should return attributes in practice")
    end
  end

  test "should be able to add attributes through schema" do
    assert_nothing_raised do
      s = nil
      Person.schema do
        s = self
        attribute("foo", "string")
      end
      assert s.attrs.has_key?("foo"), "should have saved the attribute name"
      assert_equal "string", s.attrs["foo"], "should have saved the attribute type"
    end
  end

  test "should convert symbol attributes to strings" do
    assert_nothing_raised do
      s = nil
      Person.schema do
        s = self
        attribute(:foo, :integer)
      end

      assert s.attrs.has_key?("foo"), "should have saved the attribute name as a string"
      assert_equal "integer", s.attrs["foo"], "should have saved the attribute type as a string"
    end
  end

  test "should be able to add all known attribute types" do
    assert_nothing_raised do
      ActiveResource::Schema::KNOWN_ATTRIBUTE_TYPES.each do |the_type|
        s = nil
        Person.schema do
          s = self
          attribute("foo", the_type)
        end
        assert s.attrs.has_key?("foo"), "should have saved the attribute name"
        assert_equal the_type.to_s, s.attrs["foo"], "should have saved the attribute type of: #{the_type}"
      end
    end
  end

  test "attributes should not accept unknown values" do
    bad_values = [ :oogle, :blob, "thing" ]

    bad_values.each do |bad_value|
      assert_raises(ArgumentError, "should only accept a known attribute type, but accepted: #{bad_value.inspect}") do
        Person.schema do
          attribute "key", bad_value
        end
      end
      assert_not self.respond_to?(bad_value), "should only respond to a known attribute type, but accepted: #{bad_value.inspect}"
      assert_raises(NoMethodError, "should only have methods for known attribute types, but accepted: #{bad_value.inspect}") do
        Person.schema do
          send bad_value, "key"
        end
      end
    end
  end

  test "should accept attribute types as the type's name as the method" do
    ActiveResource::Schema::KNOWN_ATTRIBUTE_TYPES.each do |the_type|
      s = nil
      Person.schema do
        s = self
        send(the_type, "foo")
      end
      assert s.attrs.has_key?("foo"), "should now have saved the attribute name"
      assert_equal the_type.to_s, s.attrs["foo"], "should have saved the attribute type of: #{the_type}"
    end
  end

  test "should accept multiple attribute names for an attribute method" do
    names = [ "foo", "bar", "baz" ]
    s = nil
    Person.schema do
      s = self
      string(*names)
    end
    names.each do |the_name|
      assert s.attrs.has_key?(the_name), "should now have saved the attribute name: #{the_name}"
      assert_equal "string", s.attrs[the_name], "should have saved the attribute as a string"
    end
  end


  #####################################################
  # What a schema does for us
  ####

  # respond_to_missing?

  test "should respond positively to attributes that are only in the schema" do
    new_attr_name = :my_new_schema_attribute
    new_attr_name_two = :another_new_schema_attribute
    assert Person.schema.blank?, "sanity check - should have a blank class schema"

    assert_not Person.new.respond_to?(new_attr_name), "sanity check - should not respond to the brand-new attribute yet"
    assert_not Person.new.respond_to?(new_attr_name_two), "sanity check - should not respond to the brand-new attribute yet"

    assert_nothing_raised do
      Person.schema = { new_attr_name.to_s => "string" }
      Person.schema { string new_attr_name_two }
    end

    assert_respond_to Person.new, new_attr_name, "should respond to the attribute in a passed-in schema, but failed on: #{new_attr_name}"
    assert_respond_to Person.new, new_attr_name_two, "should respond to the attribute from the schema, but failed on: #{new_attr_name_two}"
  end

  test "should not care about ordering of schema definitions" do
    new_attr_name = :my_new_schema_attribute
    new_attr_name_two = :another_new_schema_attribute

    assert Person.schema.blank?, "sanity check - should have a blank class schema"

    assert_not Person.new.respond_to?(new_attr_name), "sanity check - should not respond to the brand-new attribute yet"
    assert_not Person.new.respond_to?(new_attr_name_two), "sanity check - should not respond to the brand-new attribute yet"

    assert_nothing_raised do
      Person.schema { string new_attr_name_two }
      Person.schema = { new_attr_name.to_s => "string" }
    end

    assert_respond_to Person.new, new_attr_name, "should respond to the attribute in a passed-in schema, but failed on: #{new_attr_name}"
    assert_respond_to Person.new, new_attr_name_two, "should respond to the attribute from the schema, but failed on: #{new_attr_name_two}"
  end

  test "should retrieve the `Method` object" do
    new_attr_name = :my_new_schema_attribute
    new_attr_name_two = :another_new_schema_attribute
    assert Person.schema.blank?, "sanity check - should have a blank class schema"

    assert_not Person.new.respond_to?(new_attr_name), "sanity check - should not respond to the brand-new attribute yet"
    assert_not Person.new.respond_to?(new_attr_name_two), "sanity check - should not respond to the brand-new attribute yet"

    assert_nothing_raised do
      Person.schema = { new_attr_name.to_s => "string" }
      Person.schema { string new_attr_name_two }
    end

    assert_instance_of Method, Person.new.method(new_attr_name)
    assert_instance_of Method, Person.new.method(new_attr_name_two)
  end

  # method_missing effects

  test "should not give method_missing for attribute only in schema" do
    new_attr_name = :another_new_schema_attribute
    new_attr_name_two = :another_new_schema_attribute

    assert Person.schema.blank?, "sanity check - should have a blank class schema"

    assert_raises(NoMethodError, "should not have found the attribute: #{new_attr_name} as a method") do
      Person.new.send(new_attr_name)
    end
    assert_raises(NoMethodError, "should not have found the attribute: #{new_attr_name_two} as a method") do
      Person.new.send(new_attr_name_two)
    end

    Person.schema = { new_attr_name.to_s => :float }
    Person.schema { string new_attr_name_two }

    assert_nothing_raised do
      Person.new.send(new_attr_name)
      Person.new.send(new_attr_name_two)
    end
  end


  ########
  # Known attributes
  #
  # Attributes can be known to be attributes even if they aren't actually
  # 'set' on a particular instance.
  # This will only differ from 'attributes' if a schema has been set.

  test "new model should have no known attributes" do
    assert Person.known_attributes.blank?, "should have no known attributes"
    assert Person.new.known_attributes.blank?, "should have no known attributes on a new instance"
  end

  test "setting schema should set known attributes on class and instance" do
    new_schema = { "age" => "integer", "name" => "string",
      "height" => "float", "bio" => "text",
      "weight" => "decimal", "photo" => "binary",
      "alive" => "boolean", "created_at" => "timestamp",
      "thetime" => "time", "thedate" => "date", "mydatetime" => "datetime" }

    assert_nothing_raised { Person.schema = new_schema }

    assert_equal new_schema.keys.sort, Person.known_attributes.sort
    assert_equal new_schema.keys.sort, Person.new.known_attributes.sort
  end

  test "known attributes on a fetched resource should return all the attributes of the instance" do
    p = Person.find(1)
    attrs = p.known_attributes

    assert attrs.present?, "should have found some attributes!"

    p.attributes.each do |the_attr, val|
      assert attrs.include?(the_attr), "should have found attr: #{the_attr} in known attributes, but only had: #{attrs.inspect}"
    end
  end

  test "with two instances, known attributes should match the attributes of the individual instances - even if they differ" do
    matz = Person.find(1)
    rick = Person.find(6)

    m_attrs = matz.attributes.keys.sort
    r_attrs = rick.attributes.keys.sort

    assert_not_equal m_attrs, r_attrs, "should have different attributes on each model"

    assert_not_equal matz.known_attributes, rick.known_attributes, "should have had different known attributes too"
  end

  test "setting schema then fetching should add schema attributes to the instance attributes" do
    # an attribute in common with fetched instance and one that isn't
    new_schema = { "age" => "integer", "name" => "string",
      "height" => "float", "bio" => "text",
      "weight" => "decimal", "photo" => "binary",
      "alive" => "boolean", "created_at" => "timestamp",
      "thetime" => "time", "thedate" => "date", "mydatetime" => "datetime" }

    assert_nothing_raised { Person.schema = new_schema }

    matz = Person.find(1)
    known_attrs = matz.known_attributes

    matz.attributes.keys.each do |the_attr|
      assert known_attrs.include?(the_attr), "should have found instance attr: #{the_attr} in known attributes, but only had: #{known_attrs.inspect}"
    end
    new_schema.keys.each do |the_attr|
      assert known_attrs.include?(the_attr), "should have found schema attr: #{the_attr} in known attributes, but only had: #{known_attrs.inspect}"
    end
  end

  test "known attributes should be unique" do
    new_schema = { "age" => "integer", "name" => "string" }
    Person.schema = new_schema
    assert_equal Person.new(age: 20, name: "Matz").known_attributes, [ "age", "name" ]
  end

  test "clone with schema that casts values" do
    Person.cast_values = true
    Person.schema = { "age" => "integer" }
    person = Person.new({ Person.primary_key => 1, "age" => "10" }, true)

    person_c = person.clone

    assert_predicate person_c, :new?
    assert_nil person_c.send(Person.primary_key)
    assert_equal 10, person_c.age
  end

  test "known primary_key attributes should be cast" do
    Person.schema cast_values: true do
      attribute Person.primary_key, :integer
    end

    person = Person.new(Person.primary_key => "1")

    assert_equal 1, person.send(Person.primary_key)
  end

  test "cast_values: true supports implicit types" do
    Person.schema cast_values: true do
      attribute :name
    end

    person = Person.new(name: "String")

    assert_equal "String", person.name
  end

  test "known attributes should be cast" do
    Person.schema cast_values: true do
      attribute :born_on, :date
    end

    person = Person.new(born_on: "2000-01-01")

    assert_equal Date.new(2000, 1, 1), person.born_on
  end

  test "known boolean attributes should be cast as predicates" do
    Person.schema cast_values: true do
      attribute :alive, :boolean
    end

    assert_predicate Person.new(alive: "1"), :alive?
    assert_predicate Person.new(alive: "true"), :alive?
    assert_predicate Person.new(alive: true), :alive?
    assert_not_predicate Person.new, :alive?
    assert_not_predicate Person.new(alive: nil), :alive?
    assert_not_predicate Person.new(alive: "0"), :alive?
    assert_not_predicate Person.new(alive: "false"), :alive?
    assert_not_predicate Person.new(alive: false), :alive?
  end

  test "known attributes should be support default values" do
    Person.schema cast_values: true do
      attribute :name, :string, default: "Default Name"
    end

    person = Person.new

    assert_equal "Default Name", person.name
  end

  test "unknown attributes should not be cast" do
    Person.cast_values = true

    person = Person.new(age: "10")

    assert_equal "10", person.age
  end

  test "unknown attribute type raises ArgumentError" do
    assert_raises ArgumentError, match: /Unknown Attribute type: :junk/ do
      Person.schema cast_values: true do
        attribute :name, :junk
      end
    end
  end
end
