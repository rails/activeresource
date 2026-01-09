# frozen_string_literal: true

require "abstract_unit"
require "rack/utils"

class UrlEncodedFormatTest < ActiveSupport::TestCase
  test "#encode transforms a Hash into an application/x-www-form-urlencoded query string" do
    params = { "a" => 1, "b" => 2, "c" => [ 3, 4 ] }

    encoded = ActiveResource::Formats::UrlEncodedFormat.encode(params)

    assert_equal "a=1&b=2&c%5B%5D=3&c%5B%5D=4", encoded
  end

  test "#encode transforms a nested Hash into an application/x-www-form-urlencoded query string" do
    params = { "person" => { "name" => "Matz" } }

    encoded = ActiveResource::Formats::UrlEncodedFormat.encode(params)

    assert_equal "person%5Bname%5D=Matz", encoded
  end

  test "#decode transforms an application/x-www-form-urlencoded query string into a Hash" do
    decoded = ActiveResource::Formats::UrlEncodedFormat.decode("a=1")

    assert_equal({ "a" => "1" }, decoded)
  end

  test "#decode ignores a ?-prefix" do
    decoded = ActiveResource::Formats::UrlEncodedFormat.decode("?a=1")

    assert_equal({ "a" => "1" }, decoded)
  end

  test "#decode transforms an application/x-www-form-urlencoded query string with multiple params into a Hash" do
    previous_query_parser = ActiveResource::Formats::UrlEncodedFormat.query_parser
    ActiveResource::Formats::UrlEncodedFormat.query_parser = :rack
    query = URI.encode_www_form([ [ "a[]", "1" ], [ "a[]", "2" ] ])

    decoded = ActiveResource::Formats::UrlEncodedFormat.decode(query)

    assert_equal({ "a" => [ "1", "2" ] }, decoded)
  ensure
    ActiveResource::Formats::UrlEncodedFormat.query_parser = previous_query_parser
  end
end
