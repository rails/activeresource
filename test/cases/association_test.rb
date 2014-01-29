require 'abstract_unit'

require 'fixtures/person'
require 'fixtures/beast'
require 'fixtures/customer'


class AssociationTest < ActiveSupport::TestCase
  def setup
    @klass = ActiveResource::Associations::Builder::Association
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
    assert @klass.build(Person, :customers, {:class_name => 'Client'})

    assert_raise ArgumentError do
      @klass.build(Person, :customers, {:soo_invalid => true})
    end
  end

  def test_association_class_build
    assert_kind_of ActiveResource::Reflection::AssociationReflection, @klass.build(Person, :customers, {})
  end

  def test_has_many
    External::Person.send(:has_many, :people)
    assert_equal 1, External::Person.reflections.select{|name, reflection| reflection.macro.eql?(:has_many)}.count
  end

  def test_has_many_on_new_record
    Post.send(:has_many, :topics)
    Topic.stubs(:find).returns([:unexpected_response])
    assert_equal [], Post.new.topics.to_a
  end

  def test_has_one
    External::Person.send(:has_one, :customer)
    assert_equal 1, External::Person.reflections.select{|name, reflection| reflection.macro.eql?(:has_one)}.count
  end

  def test_belongs_to
    External::Person.belongs_to(:Customer)
    assert_equal 1, External::Person.reflections.select{|name, reflection| reflection.macro.eql?(:belongs_to)}.count
  end

  def test_defines_belongs_to_finder_method_with_instance_variable_cache
    Person.defines_belongs_to_finder_method(:customer, Customer, 'customer_id')

    person = Person.new
    assert !person.instance_variable_defined?(:@customer)
    person.stubs(:customer_id).returns(2)
    Customer.expects(:find).with(2).once()
    2.times{person.customer}
    assert person.instance_variable_defined?(:@customer)
  end

  def test_belongs_to_with_finder_key
    Person.defines_belongs_to_finder_method(:customer, Customer, 'customer_id')

    person = Person.new
    person.stubs(:customer_id).returns(1)
    Customer.expects(:find).with(1).once()
    person.customer
  end

  def test_belongs_to_with_nil_finder_key
    Person.defines_belongs_to_finder_method(:customer, Customer, 'customer_id')

    person = Person.new
    person.stubs(:customer_id).returns(nil)
    Customer.expects(:find).with(nil).never()
    person.customer
  end
end
