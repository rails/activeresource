# frozen_string_literal: true

require "abstract_unit"

require "fixtures/product"

class InheritenceTest < ActiveSupport::TestCase
  def test_sub_class_retains_ancestor_headers
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/sub_products/1.json",
               { "Accept" => "application/json", "X-Inherited-Header" => "present" },
               { id: 1, name: "Sub Product" }.to_json,
               200
    end

    sub_product = SubProduct.find(1)
    assert_equal "SubProduct", sub_product.class.to_s
  end
end
