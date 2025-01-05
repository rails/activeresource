# frozen_string_literal: true

require "abstract_unit"
require "fixtures/person"

class NotificationsTest < ActiveSupport::TestCase
  def setup
    matz = { person: { id: 1, name: "Matz" } }
    @people = { people: [ matz ] }.to_json

    ActiveResource::HttpMock.respond_to do |mock|
      mock.get  "/people.json?name=Matz", { "Accept" => "application/json" }, @people
      mock.post "/people.json", { "Content-Type" => "application/json" }, nil, 201, "Location" => "/people/5.json"
    end
  end

  def test_get_request_with_params
    payload = capture_notifications { Person.where(name: "Matz") }

    assert_equal :get, payload[:method]
    assert_equal "http://37s.sunrise.i:3000/people.json?name=Matz", payload[:request_uri]
    assert_equal({ "Accept" => "application/json" }, payload[:headers])
    assert_nil payload[:body]
    assert_kind_of ActiveResource::Response, payload[:result]
  end

  def test_post_request_with_body
    payload = capture_notifications { Person.create!(name: "Matz") }

    assert_equal :post, payload[:method]
    assert_equal "http://37s.sunrise.i:3000/people.json", payload[:request_uri]
    assert_equal({ "Content-Type" => "application/json" }, payload[:headers])
    assert_equal({ "person" => { "name" => "Matz" } }.to_json, payload[:body])
    assert_kind_of ActiveResource::Response, payload[:result]
  end

  def capture_notifications(&block)
    payload = nil
    ActiveSupport::Notifications.subscribed ->(event) { payload = event.payload }, "request.active_resource", &block
    payload
  end
end
