# frozen_string_literal: true

require "abstract_unit"
require "fixtures/person"
require "fixtures/street_address"
require "active_support/core_ext/hash/conversions"

class ReadonlyAttributesTest < ActiveSupport::TestCase
  def setup
    @matz = { id: 1, name: "Matz", readonly: "readonly" }.to_json

    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1.json", {}, @matz
    end

    Person.user = nil
    Person.password = nil
    Person.attr_readonly :readonly
  end

  def teardown
    ActiveResource::HttpMock.reset!
  end

  def test_readonly_attribute
    assert_equal({ "id" => 1, "name" => "Matz", "readonly" => "readonly" }, Person.find(1).attributes)
    assert_equal(false, JSON.parse(Person.find(1).encode).key?("readonly"))
  end
end
