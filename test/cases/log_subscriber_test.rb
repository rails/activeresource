require "abstract_unit"
require "fixtures/person"
require "active_support/log_subscriber/test_helper"
require "active_resource/log_subscriber"
require "active_support/core_ext/hash/conversions"

class LogSubscriberTest < ActiveSupport::TestCase
  include ActiveSupport::LogSubscriber::TestHelper

  def setup
    super

    @matz = { :person => { :id => 1, :name => 'Matz' } }.to_json
    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people/1.json", {}, @matz
      mock.post "/people.json", {}, @matz, 201, 'Location' => '/people/1.json'
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
    assert_match(/\-\-\> 200 200 33/, @logger.logged(:info)[1])
  end

  def test_request_with_params_notification
    Person.create(name: 'Matz')
    wait
    assert_equal 3, @logger.logged(:info).size
    assert_equal "POST http://37s.sunrise.i:3000/people.json", @logger.logged(:info)[0]
    assert_equal 'Params sent: {"person"=>{"name"=>"Matz"}}', @logger.logged(:info)[1]
    assert_match(/\-\-\> 201 201 33/, @logger.logged(:info)[2])
  end
end
