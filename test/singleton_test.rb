# frozen_string_literal: true

require "abstract_unit"
require "fixtures/weather"
require "fixtures/inventory"

class SingletonTest < ActiveSupport::TestCase
  def setup_weather
    weather = { status: "Sunny", temperature: 67 }
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get    "/weather.json", {}, weather.to_json
      mock.get    "/weather.json?degrees=fahrenheit", {}, weather.merge(temperature: 100).to_json
      mock.post   "/weather.json", {}, weather.to_json, 201, "Location" => "/weather.json"
      mock.delete "/weather.json", {}, nil
      mock.put    "/weather.json", {}, nil, 204
    end
  end

  def setup_weather_not_found
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/weather.json", {}, nil, 404
    end
  end

  def setup_inventory
    inventory = { status: "Sold Out", total: 10, used: 10 }.to_json

    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/products/5/inventory.json", {}, inventory
    end
  end

  def test_custom_singleton_name
    assert_equal "dashboard", WeatherDashboard.singleton_name
  end

  def test_singleton_path
    assert_equal "/weather.json", Weather.singleton_path
  end

  def test_singleton_path_with_parameters
    assert_equal "/weather.json?degrees=fahrenheit", Weather.singleton_path(degrees: "fahrenheit")
    assert_equal "/weather.json?degrees=false", Weather.singleton_path(degrees: false)
    assert_equal "/weather.json?degrees=", Weather.singleton_path(degrees: nil)

    assert_equal "/weather.json?degrees=fahrenheit", Weather.singleton_path("degrees" => "fahrenheit")

    # Use include? because ordering of param hash is not guaranteed
    path = Weather.singleton_path(degrees: "fahrenheit", lunar: true)
    assert path.include?("weather.json")
    assert path.include?("degrees=fahrenheit")
    assert path.include?("lunar=true")

    path = Weather.singleton_path(days: ["monday", "saturday and sunday", nil, false])
    assert_equal "/weather.json?days%5B%5D=monday&days%5B%5D=saturday+and+sunday&days%5B%5D=&days%5B%5D=false", path

    path = Inventory.singleton_path(product_id: 5)
    assert_equal "/products/5/inventory.json", path

    path = Inventory.singleton_path({ product_id: 5 }, { sold: true })
    assert_equal "/products/5/inventory.json?sold=true", path
  end

  def test_find_singleton
    setup_weather
    weather = Weather.send(:find_singleton, Hash.new)
    assert_not_nil weather
    assert_equal "Sunny", weather.status
    assert_equal 67, weather.temperature
  end

  def test_find
    setup_weather
    weather = Weather.find
    assert_not_nil weather
    assert_equal "Sunny", weather.status
    assert_equal 67, weather.temperature
  end

  def test_find_with_param_options
    setup_inventory
    inventory = Inventory.find(params: { product_id: 5 })

    assert_not_nil inventory
    assert_equal "Sold Out", inventory.status
    assert_equal 10, inventory.used
    assert_equal 10, inventory.total
    assert_equal({ product_id: 5 }, inventory.prefix_options)
  end

  def test_find_with_query_options
    setup_weather

    weather = Weather.find(params: { degrees: "fahrenheit" })
    assert_not_nil weather
    assert_equal "Sunny", weather.status
    assert_equal 100, weather.temperature
  end

  def test_not_found
    setup_weather_not_found

    assert_raise ActiveResource::ResourceNotFound do
      Weather.find
    end
  end

  def test_create_singleton
    setup_weather
    weather = Weather.create(status: "Sunny", temperature: 67)
    assert_not_nil weather
    assert_equal "Sunny", weather.status
    assert_equal 67, weather.temperature
  end

  def test_destroy
    setup_weather

    # First Create the Weather
    weather = Weather.create(status: "Sunny", temperature: 67)
    assert_not_nil weather

    # Now Destroy it
    weather.destroy
  end

  def test_update
    setup_weather

    # First Create the Weather
    weather = Weather.create(status: "Sunny", temperature: 67)
    assert_not_nil weather

    # Then update it
    weather.status = "Rainy"
    weather.save
  end
end
