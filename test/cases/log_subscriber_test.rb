# frozen_string_literal: true

require "abstract_unit"
require "fixtures/person"
require "active_support/log_subscriber/test_helper"
require "active_resource/log_subscriber"
require "active_support/core_ext/hash/conversions"

class LogSubscriberTest < ActiveSupport::TestCase
  include ActiveSupport::LogSubscriber::TestHelper

  def setup
    super

    @matz = { person: { id: 1, name: "Matz" } }.to_json
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1.json", {}, @matz
      mock.get "/people/2.json", {}, nil, 404
      mock.get "/people/3.json", {}, nil, 502
    end

    ActiveResource::LogSubscriber.attach_to :active_resource
  end

  def set_logger(logger)
    ActiveResource::Base.logger = logger
  end

  def test_request_notification
    Person.find(1)
    wait
    assert_equal 2, @logger.logged(:info).size
    assert_equal "GET http://37s.sunrise.i:3000/people/1.json", @logger.logged(:info)[0]
    assert_match(/--> 200 200 33/, @logger.logged(:info)[1])
  end

  def test_failure_error_log
    Person.find(2)
  rescue
    wait
    assert_equal 2, @logger.logged(:error).size
    assert_equal "GET http://37s.sunrise.i:3000/people/2.json", @logger.logged(:error)[0]
    assert_match(/--> 404 404 0/, @logger.logged(:error)[1])
  end

  def test_server_error_log
    Person.find(3)
  rescue
    wait
    assert_equal 2, @logger.logged(:error).size
    assert_equal "GET http://37s.sunrise.i:3000/people/3.json", @logger.logged(:error)[0]
    assert_match(/--> 502 502 0/, @logger.logged(:error)[1])
  end

  def test_connection_failure
    Person.find(99)
  rescue
    wait
    assert_equal 2, @logger.logged(:error).size
    assert_equal "GET http://37s.sunrise.i:3000/people/99.json", @logger.logged(:error)[0]
    assert_match(/--> 523 ActiveResource connection error 0/, @logger.logged(:error)[1])
  end
end
