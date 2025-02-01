# frozen_string_literal: true

require "abstract_unit"
require "fixtures/person"

class RescuableTest < ActiveSupport::TestCase
  class Rescuable < ActiveResource::Base
    class Error < StandardError
    end

    self.site = "http://37s.sunrise.i:3000"

    rescue_from ActiveResource::ResourceNotFound, with: :rescue_not_found
    rescue_from ActiveResource::UnauthorizedAccess, with: :rescue_unauthorized
    rescue_from ActiveResource::BadRequest, with: ->(*) { raise Error, "Bad Request" }

    schema do
      attribute :not_found, :boolean
      attribute :unauthorized, :boolean
    end

    def rescue_not_found
      self.not_found = true
    end

    def rescue_unauthorized
      self.unauthorized = true
    end
  end

  def test_rescue_from_catches_exceptions_raised_during_reload
    ActiveResource::HttpMock.respond_to.get "/rescuables/1.json", {}, nil, 404
    resource = Rescuable.new({ id: 1 }, true)

    assert_nothing_raised { resource.reload }

    assert_predicate resource, :not_found?
  end

  def test_rescue_from_catches_exceptions_raised_during_create
    ActiveResource::HttpMock.respond_to.post "/rescuables.json", {}, nil, 401
    resource = Rescuable.new

    assert_nothing_raised { resource.save! }

    assert_predicate resource, :unauthorized?
  end

  def test_rescue_from_catches_exceptions_raised_during_destroy
    ActiveResource::HttpMock.respond_to.delete "/rescuables/1.json", {}, nil, 401
    resource = Rescuable.new({ id: 1 }, true)

    assert_nothing_raised { resource.destroy }

    assert_predicate resource, :unauthorized?
  end

  def test_rescue_from_catches_exceptions_raised_during_save
    ActiveResource::HttpMock.respond_to.put "/rescuables/1.json", {}, nil, 401
    resource = Rescuable.new({ id: 1 }, true)

    assert_nothing_raised { resource.save! }

    assert_predicate resource, :unauthorized?
  end

  def test_rescue_from_catches_exceptions_raised_during_update
    ActiveResource::HttpMock.respond_to.put "/rescuables/1.json", {}, nil, 401
    resource = Rescuable.new({ id: 1 }, true)

    assert_nothing_raised { resource.update_attributes(saved: true) }

    assert_predicate resource, :unauthorized?
  end

  def test_rescue_from_re_raises_exceptions_raised_during_save
    ActiveResource::HttpMock.respond_to.post "/rescuables.json", {}, {}, 400

    assert_raises Rescuable::Error, match: "Bad Request" do
      Rescuable.create!
    end
  end
end
