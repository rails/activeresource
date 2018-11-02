# frozen_string_literal: true

require "abstract_unit"

require "fixtures/person"
require "fixtures/customer"



class ReflectionTest < ActiveSupport::TestCase
  def test_correct_class_attributes
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, {})
    assert_equal :people, object.name
    assert_equal :test, object.macro
    assert_equal({}, object.options)
  end

  def test_correct_class_name_matching_without_class_name
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, {})
    assert_equal Person, object.klass
  end

  def test_correct_class_name_matching_as_string
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, class_name: "Person")
    assert_equal Person, object.klass
  end

  def test_correct_class_name_matching_as_symbol
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, class_name: :person)
    assert_equal Person, object.klass
  end

  def test_correct_class_name_matching_as_class
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, class_name: Person)
    assert_equal Person, object.klass
  end

  def test_correct_class_name_matching_as_string_with_namespace
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, class_name: "external/person")
    assert_equal External::Person, object.klass
  end

  def test_correct_class_name_matching_as_plural_string_with_namespace
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, class_name: "external/profile_data")
    assert_equal External::ProfileData, object.klass
  end

  def test_foreign_key_method_with_no_foreign_key_option
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :person, {})
    assert_equal "person_id", object.foreign_key
  end

  def test_foreign_key_method_with_with_foreign_key_option
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, foreign_key: "client_id")
    assert_equal "client_id", object.foreign_key
  end

  def test_creation_of_reflection
    Person.reflections = {}
    object = Person.create_reflection(:test, :people, {})
    assert_equal ActiveResource::Reflection::AssociationReflection, object.class
    assert_equal 1, Person.reflections.count
    assert_equal Person, Person.reflections[:people].klass
  end
end
