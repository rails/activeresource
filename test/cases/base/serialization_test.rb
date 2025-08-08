# frozen_string_literal: true

require "abstract_unit"
require "fixtures/person"

class SerializationTest < ActiveSupport::TestCase
  test ".load delegates to the .coder" do
    resource = Person.new(id: 1, name: "Matz")

    encoded = Person.load(resource.encode)

    assert_equal resource.id, encoded.id
    assert_equal resource.name, encoded.name
    assert_equal resource.attributes, encoded.attributes
  end

  test ".dump delegates to the default .coder" do
    resource = Person.new(id: 1, name: "Matz")

    encoded = Person.dump(resource)

    assert_equal resource.encode, encoded
    assert_equal({ person: { id: 1, name: "Matz" } }.to_json, encoded)
  end

  test ".dump delegates to a configured .coder method name" do
    Person.coder = ActiveResource::Coder.new(Person, :serializable_hash)
    resource = Person.new(id: 1, name: "Matz")

    encoded = Person.dump(resource)

    assert_equal resource.serializable_hash, encoded
  ensure
    Person.coder = ActiveResource::Coder.new(Person)
  end

  test ".dump delegates to a configured .coder callable" do
    Person.coder = ActiveResource::Coder.new(Person) { |value| value.serializable_hash }
    resource = Person.new(id: 1, name: "Matz")

    encoded = Person.dump(resource)

    assert_equal resource.serializable_hash, encoded
  ensure
    Person.coder = ActiveResource::Coder.new(Person)
  end

  test "#load returns nil when the encoded value is nil" do
    assert_nil Person.coder.load(nil)
  end

  test "#load decodes a String into an instance" do
    resource = Person.new(id: 1, name: "Matz")

    decoded = Person.coder.load(resource.encode)

    assert_equal resource, decoded
  end

  test "#load decodes a Hash into an instance" do
    resource = Person.new(id: 1, name: "Matz")

    decoded = Person.coder.load(resource.serializable_hash)

    assert_equal resource.id, decoded.id
    assert_equal resource.name, decoded.name
    assert_equal resource.attributes, decoded.attributes
  end

  test "#load builds the instance as persisted when the default primary key is present" do
    resource = Person.new(id: 1, name: "Matz")

    decoded = Person.coder.load(resource.encode)

    assert_predicate decoded, :persisted?
    assert_not_predicate decoded, :new_record?
  end

  test "#load builds the instance as persisted when the configured primary key is present" do
    Person.primary_key = "pk"
    resource = Person.new(pk: 1, name: "Matz")

    decoded = Person.coder.load(resource.encode)

    assert_equal 1, decoded.id
    assert_predicate decoded, :persisted?
    assert_not_predicate decoded, :new_record?
  ensure
    Person.primary_key = "id"
  end

  test "#load builds the instance as a new record when the default primary key is absent" do
    resource = Person.new(name: "Matz")

    decoded = Person.coder.load(resource.encode)

    assert_nil decoded.id
    assert_not_predicate decoded, :persisted?
    assert_predicate decoded, :new_record?
  end

  test "#load builds the instance as a new record when the configured primary key is absent" do
    Person.primary_key = "pk"
    resource = Person.new(name: "Matz")

    decoded = Person.coder.load(resource.encode)

    assert_nil decoded.id
    assert_not_predicate decoded, :persisted?
    assert_predicate decoded, :new_record?

    Person.primary_key = "id"
  end

  test "#dump encodes resources" do
    resource = Person.new(id: 1, name: "Matz")

    encoded = Person.coder.dump(resource)

    assert_equal resource.encode, encoded
    assert_equal({ person: { id: 1, name: "Matz" } }.to_json, encoded)
  end

  test "#dump raises an ArgumentError is passed anything but an ActiveResource::Base" do
    assert_raises ArgumentError, match: "expected value to be Person, but was Integer" do
      Person.coder.dump(1)
    end
  end

  test "#dump returns nil when the resource is nil" do
    assert_nil Person.coder.dump(nil)
  end

  test "#dump with an encoder method name returns nil when the resource is nil" do
    coder = ActiveResource::Coder.new(Person, :serializable_hash)

    assert_nil coder.dump(nil)
  end

  test "#dump with an encoder method name encodes resources" do
    coder = ActiveResource::Coder.new(Person, :serializable_hash)
    resource = Person.new(id: 1, name: "Matz")

    encoded = coder.dump(resource)

    assert_equal resource.serializable_hash, encoded
  end

  test "#dump with an encoder block encodes resources" do
    coder = ActiveResource::Coder.new(Person) { |value| value.serializable_hash }
    resource = Person.new(id: 1, name: "Matz")

    encoded = coder.dump(resource)

    assert_equal resource.serializable_hash, encoded
  end
end
