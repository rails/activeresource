# frozen_string_literal: true

require "abstract_unit"

class UrlEncodedFormatTest < ActiveSupport::TestCase
  test "#encode transforms a Hash into an application/x-www-form-urlencoded query string" do
    params = { "a" => 1, "b" => 2, "c" => [ 3, 4 ] }

    encoded = ActiveResource::Formats::UrlEncodedFormat.encode(params)

    assert_equal "a=1&b=2&c%5B%5D=3&c%5B%5D=4", encoded
  end
end
