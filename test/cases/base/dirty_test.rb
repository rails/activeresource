require 'abstract_unit'
require 'active_support/core_ext/hash/conversions'
require "fixtures/person"
require "fixtures/street_address"

########################################################################
# Testing the schema of your Active Resource models
########################################################################
class DirtyTest < ActiveModel::TestCase
  def setup
    @person = Person.new
  end

  def teardown
    Person.schema = nil # hack to stop test bleedthrough...
  end

  test "setting attribute will result in change" do
    assert !@person.changed?
    assert !@person.name_changed?
    @person.name = "Ringo"
    assert @person.changed?
    assert @person.name_changed?
  end

  test "list of changed attribute keys" do
    assert_equal [], @person.changed
    @person.name = "Paul"
    assert_equal ['name'], @person.changed
  end

  test "changes to attribute values" do
    assert !@person.changes['name']
    @person.name = "John"
    assert_equal [nil, "John"], @person.changes['name']
  end

  test "changes accessible through both strings and symbols" do
    @person.name = "David"
    assert_not_nil @person.changes[:name]
    assert_not_nil @person.changes['name']
  end

  test "attribute mutation" do
    @person.name = "Yam"
    @person.instance_variable_get(:@changed_attributes).clear
    assert !@person.name_changed?
    @person.name.replace("Hadad")
    assert !@person.name_changed?
    @person.name_will_change!
    @person.name.replace("Baal")
    assert @person.name_changed?
  end

  test "resetting attribute" do
    @person.name = "Bob"
    @person.reset_name!
    assert_nil @person.name
    assert !@person.name_changed?
  end

  test "setting color to same value should not result in change being recorded" do
    @person.stubs(:create).returns(true)
    @person.color = "red"
    assert @person.color_changed?
    @person.save
    assert !@person.color_changed?
    assert !@person.changed?
    @person.color = "red"
    assert !@person.color_changed?
    assert !@person.changed?
  end

  test "saving should reset model's changed status" do
    @person.stubs(:create).returns(true)
    @person.name = "Alf"
    assert @person.changed?
    @person.save
    assert !@person.changed?
    assert !@person.name_changed?
  end

  test "saving should preserve previous changes" do
    @person.stubs(:create).returns(true)
    @person.name = "Jericho Cane"
    @person.save
    assert_equal [nil, "Jericho Cane"], @person.previous_changes['name']
  end

  test "previous value is preserved when changed after save" do
    @person.stubs(:create).returns(true)
    assert_equal({}, @person.changed_attributes)
    @person.name = "Paul"
    assert_equal({ "name" => nil }, @person.changed_attributes)

    @person.save

    @person.name = "John"
    assert_equal({ "name" => "Paul" }, @person.changed_attributes)
  end

  test "changing the same attribute multiple times retains the correct original value" do
    @person.stubs(:create).returns(true)
    @person.name = "Otto"
    @person.save
    @person.name = "DudeFella ManGuy"
    @person.name = "Mr. Manfredgensonton"
    assert_equal ["Otto", "Mr. Manfredgensonton"], @person.name_change
    assert_equal @person.name_was, "Otto"
  end
end
