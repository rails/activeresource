# frozen_string_literal: true

require "abstract_unit"

require "fixtures/product"
require "fixtures/inventory"

class ActiveResource::Associations::Builder::HasOneTest < ActiveSupport::TestCase
  def setup
    @klass = ActiveResource::Associations::Builder::HasOne
  end

  def test_validations_for_instance
    object = @klass.new(Product, :inventory, {})
    assert_equal({}, object.send(:validate_options))
  end

  def test_instance_build
    object = @klass.new(Product, :inventory, {})
    Product.expects(:defines_has_one_finder_method).with(kind_of(ActiveResource::Reflection::AssociationReflection))

    reflection = object.build

    assert_kind_of ActiveResource::Reflection::AssociationReflection, reflection
    assert_equal :inventory, reflection.name
    assert_equal Inventory, reflection.klass
  end
end
