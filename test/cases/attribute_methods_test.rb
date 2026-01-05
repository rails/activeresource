# frozen_string_literal: true

require "abstract_unit"
require "fixtures/person"

class AttributeMethodsTest < ActiveSupport::TestCase
  setup :setup_response

  test "write_attribute string" do
    matz = Person.find(1)

    assert_changes -> { matz.name }, to: "matz" do
      matz.write_attribute("name", "matz")
    end
  end

  test "write_attribute symbol" do
    matz = Person.find(1)

    assert_changes -> { matz.name }, to: "matz" do
      matz.write_attribute(:name, "matz")
    end
  end

  test "write_attribute id" do
    matz = Person.find(1)

    assert_changes -> { matz.id }, from: 1, to: "2" do
      matz.write_attribute(:id, "2")
    end
  end

  test "write_attribute primary key" do
    previous_primary_key = Person.primary_key
    Person.primary_key = "pk"
    matz = Person.find(1)

    assert_changes -> { matz.id }, from: 1, to: "2" do
      matz.write_attribute(:id, "2")
    end
    assert_changes -> { matz.id }, from: "2", to: 1 do
      matz.write_attribute("pk", 1)
    end
    assert_changes -> { matz.id }, from: 1, to: "2" do
      matz.id = "2"
    end
  ensure
    Person.primary_key = previous_primary_key
  end

  test "write_attribute an unknown attribute" do
    person = Person.new

    person.write_attribute("unknown", true)

    assert_predicate person, :unknown
  end

  test "read_attribute" do
    matz = Person.find(1)

    assert_equal "Matz", matz.read_attribute("name")
    assert_equal "Matz", matz.read_attribute(:name)
  end

  test "read_attribute id" do
    matz = Person.find(1)

    assert_equal 1, matz.read_attribute("id")
    assert_equal 1, matz.read_attribute(:id)
  end

  test "read_attribute primary key" do
    previous_primary_key = Person.primary_key
    Person.primary_key = "pk"
    matz = Person.find(1)

    assert_equal 1, matz.id
    assert_equal 1, matz.read_attribute("pk")
    assert_equal 1, matz.read_attribute(:pk)
  ensure
    Person.primary_key = previous_primary_key
  end

  test "read_attribute unknown attribute" do
    person = Person.new

    assert_nil person.read_attribute("unknown")
  end
end
