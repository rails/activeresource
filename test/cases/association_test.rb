# frozen_string_literal: true

require "abstract_unit"

require "fixtures/person"
require "fixtures/beast"
require "fixtures/customer"


class AssociationTest < ActiveSupport::TestCase
  def setup
    @klass = ActiveResource::Associations::Builder::Association
    @reflection = ActiveResource::Reflection::AssociationReflection.new :belongs_to, :customer, {}
  end


  def test_validations_for_instance
    object = @klass.new(Person, :customers, {})
    assert_equal({}, object.send(:validate_options))
  end

  def test_instance_build
    object = @klass.new(Person, :customers, {})
    assert_kind_of ActiveResource::Reflection::AssociationReflection, object.build
  end

  def test_valid_options
    assert @klass.build(Person, :customers, class_name: "Client")

    assert_raise ArgumentError do
      @klass.build(Person, :customers, soo_invalid: true)
    end
  end

  def test_association_class_build
    assert_kind_of ActiveResource::Reflection::AssociationReflection, @klass.build(Person, :customers, {})
  end

  def test_has_many
    External::Person.send(:has_many, :people)
    assert_equal 1, External::Person.reflections.select { |name, reflection| reflection.macro.eql?(:has_many) }.count

    ActiveResource::HttpMock.respond_to.get "/people.json?person_id=1", {}, { people: [ { id: 2, name: "Related" } ] }.to_json
    person = External::Person.new({ id: 1 }, true)

    people = person.people

    assert_equal [ "Related" ], people.map(&:name)
  ensure
    reflection = External::Person.reflections.delete(:people)
    External::Person.remove_method(:people) if reflection
  end

  def test_has_many_with_primary_key
    External::Person.has_many(:people, primary_key: :parent_id)

    ActiveResource::HttpMock.respond_to.get "/people.json?person_id=1", {}, { people: [ { id: 2, name: "Related" } ] }.to_json
    person = External::Person.new({ parent_id: 1 }, true)

    people = person.people

    assert_equal [ "Related" ], people.map(&:name)
  ensure
    reflection = External::Person.reflections.delete(:people)
    External::Person.remove_method(:people) if reflection
  end

  def test_has_many_with_foreign_key
    External::Person.has_many(:people, foreign_key: :parent_id)

    ActiveResource::HttpMock.respond_to.get "/people.json?parent_id=1", {}, { people: [ { id: 2, name: "Related" } ] }.to_json
    person = External::Person.new({ id: 1 }, true)

    people = person.people

    assert_equal [ "Related" ], people.map(&:name)
  ensure
    reflection = External::Person.reflections.delete(:people)
    External::Person.remove_method(:people) if reflection
  end

  def test_has_many_chain
    External::Person.send(:has_many, :people)

    ActiveResource::HttpMock.respond_to.get "/people.json?name=Related&person_id=1", {}, { people: [ { id: 2, name: "Related" } ] }.to_json
    person = External::Person.new({ id: 1 }, true)

    people = person.people.where(name: "Related")

    assert_equal [ "Related" ], people.map(&:name)
  ensure
    reflection = External::Person.reflections.delete(:people)
    External::Person.remove_method(:people) if reflection
  end

  def test_has_many_on_new_record
    Post.send(:has_many, :topics)
    Topic.stubs(:find).returns([ :unexpected_response ])
    assert_equal [], Post.new.topics.to_a
  end

  def test_has_one
    External::Person.send(:has_one, :customer)
    assert_equal 1, External::Person.reflections.select { |name, reflection| reflection.macro.eql?(:has_one) }.count

    ActiveResource::HttpMock.respond_to.get "/people/1/customer.json", {}, { person: { id: 2, name: "Customer" } }.to_json
    person = External::Person.new({ id: 1 }, true)

    customer = person.customer

    assert_equal "Customer", customer.name
  ensure
    reflection = External::Person.reflections.delete(:customer)
    External::Person.remove_method(:customer) if reflection
  end

  def test_has_one_singleton
    External::Person.send(:has_one, :weather)

    ActiveResource::HttpMock.respond_to.get "/weather.json?person_id=1", {}, { weather: { id: 1, status: "Sunshine" } }.to_json
    person = External::Person.new({ id: 1 }, true)

    weather = person.weather

    assert_equal "Sunshine", weather.status
  ensure
    reflection = External::Person.reflections.delete(:weather)
    External::Person.remove_method(:weather) if reflection
  end

  def test_has_one_with_primary_key
    External::Person.send(:has_one, :customer, primary_key: :customer_id)

    ActiveResource::HttpMock.respond_to.get "/people/1/customer.json", {}, { person: { id: 2, name: "Customer" } }.to_json
    person = External::Person.new({ customer_id: 1 }, true)

    customer = person.customer

    assert_equal "Customer", customer.name
  ensure
    reflection = External::Person.reflections.delete(:customer)
    External::Person.remove_method(:customer) if reflection
  end

  def test_has_one_singleton_with_primary_key
    External::Person.send(:has_one, :weather, primary_key: :person_id)

    ActiveResource::HttpMock.respond_to.get "/weather.json?person_id=1", {}, { weather: { id: 1, status: "Sunshine" } }.to_json
    person = External::Person.new({ person_id: 1 }, true)

    weather = person.weather

    assert_equal "Sunshine", weather.status
  ensure
    reflection = External::Person.reflections.delete(:weather)
    External::Person.remove_method(:weather) if reflection
  end

  def test_has_one_singleton_with_foreign_key
    previous_prefix = Weather.prefix
    Weather.prefix = "/people/:owner_id/"

    External::Person.send(:has_one, :weather, foreign_key: :owner_id)

    ActiveResource::HttpMock.respond_to.get "/people/1/weather.json", {}, { weather: { id: 1, status: "Sunshine" } }.to_json
    person = External::Person.new({ id: 1 }, true)

    weather = person.weather

    assert_equal "Sunshine", weather.status
  ensure
    Weather.prefix = previous_prefix
    reflection = External::Person.reflections.delete(:weather)
    External::Person.remove_method(:weather) if reflection
  end

  def test_belongs_to
    External::Person.belongs_to(:Customer)
    assert_equal 1, External::Person.reflections.select { |name, reflection| reflection.macro.eql?(:belongs_to) }.count
  end

  def test_defines_belongs_to_finder_method_with_instance_variable_cache
    Person.defines_belongs_to_finder_method(@reflection)

    person = Person.new
    assert_not person.instance_variable_defined?(:@customer)
    person.stubs(:customer_id).returns(2)
    Customer.expects(:find).with(2).once()
    2.times { person.customer }
    assert person.instance_variable_defined?(:@customer)
  end

  def test_belongs_to_with_finder_key
    Person.defines_belongs_to_finder_method(@reflection)

    person = Person.new
    person.stubs(:customer_id).returns(1)
    Customer.expects(:find).with(1).once()
    person.customer
  end

  def test_belongs_to_with_nil_finder_key
    Person.defines_belongs_to_finder_method(@reflection)

    person = Person.new
    person.stubs(:customer_id).returns(nil)
    Customer.expects(:find).with(nil).never()
    person.customer
  end

  def test_inverse_associations_do_not_create_circular_dependencies
    code = <<-CODE
      class Park < ActiveResource::Base
        has_many :trails
      end

      class Trail < ActiveResource::Base
        belongs_to :park
      end
    CODE

    assert_nothing_raised do
      eval code
    end
  end
end
