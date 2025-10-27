# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/hash/conversions"
require "active_support/concern"
require "fixtures/weather"

module CallbackHistory
  extend ActiveSupport::Concern

  class_methods do
    def callback_string(callback_method)
      "history << [#{callback_method.to_sym.inspect}, :string]"
    end

    def callback_proc(callback_method)
      Proc.new { |model| model.history << [ callback_method, :proc ] }
    end

    def define_callback_method(callback_method)
      define_method(callback_method) do
        self.history << [ callback_method, :method ]
      end
      send(callback_method, :"#{callback_method}")
    end

    def callback_object(callback_method)
      klass = Class.new
      klass.send(:define_method, callback_method) do |model|
        model.history << [ callback_method, :object ]
      end
      klass.new
    end
  end

  included do
    ActiveResource::Callbacks::CALLBACKS.each do |callback_method|
      next if callback_method.to_s =~ /^around_/
      define_callback_method(callback_method)
      send(callback_method, callback_proc(callback_method))
      send(callback_method, callback_object(callback_method))
      send(callback_method) { |model| model.history << [ callback_method, :block ] }
    end
  end

  def history
    @history ||= []
  end
end

class Developer < ActiveResource::Base
  include CallbackHistory

  self.site = "http://37s.sunrise.i:3000"
end

Weather.include CallbackHistory

class CallbacksTest < ActiveSupport::TestCase
  def setup
    @developer_attrs = { id: 1, name: "Guillermo", salary: 100_000 }
    @developer = { "developer" => @developer_attrs }.to_json
    @weather_attrs = { status: "Sunny", temperature: 67 }
    @weather = { weather: @weather_attrs }.to_json
    ActiveResource::HttpMock.respond_to do |mock|
      mock.post   "/developers.json",   {}, @developer, 201, "Location" => "/developers/1.json"
      mock.get    "/developers/1.json", {}, @developer
      mock.put    "/developers/1.json", {}, nil, 204
      mock.delete "/developers/1.json", {}, nil, 200
      mock.get    "/weather.json", {}, @weather
      mock.post   "/weather.json", {}, @weather, 201, "Location" => "/weather.json"
      mock.delete "/weather.json", {}, nil
      mock.put    "/weather.json", {}, nil, 204
    end
  end

  def test_valid?
    developer = Developer.new
    developer.valid?
    assert_equal [
      [ :before_validation,           :method ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :after_validation,            :method ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ]
    ], developer.history
  end

  def test_create
    developer = Developer.create(@developer_attrs)
    assert_equal [
      [ :before_validation,           :method ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :after_validation,            :method ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
      [ :before_save,                 :method ],
      [ :before_save,                 :proc   ],
      [ :before_save,                 :object ],
      [ :before_save,                 :block  ],
      [ :before_create,               :method ],
      [ :before_create,               :proc   ],
      [ :before_create,               :object ],
      [ :before_create,               :block  ],
      [ :after_create,                :method ],
      [ :after_create,                :proc   ],
      [ :after_create,                :object ],
      [ :after_create,                :block  ],
      [ :after_save,                  :method ],
      [ :after_save,                  :proc   ],
      [ :after_save,                  :object ],
      [ :after_save,                  :block  ]
    ], developer.history
  end

  def test_create_singleton
    weather = Weather.create(@weather_attrs)
    assert_equal [
      [ :before_validation,           :method ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :after_validation,            :method ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
      [ :before_save,                 :method ],
      [ :before_save,                 :proc   ],
      [ :before_save,                 :object ],
      [ :before_save,                 :block  ],
      [ :before_create,               :method ],
      [ :before_create,               :proc   ],
      [ :before_create,               :object ],
      [ :before_create,               :block  ],
      [ :after_create,                :method ],
      [ :after_create,                :proc   ],
      [ :after_create,                :object ],
      [ :after_create,                :block  ],
      [ :after_save,                  :method ],
      [ :after_save,                  :proc   ],
      [ :after_save,                  :object ],
      [ :after_save,                  :block  ]
    ], weather.history
  end

  def test_reload
    developer = Developer.find(1)
    developer.reload
    assert_equal [
      [ :before_reload,               :method ],
      [ :before_reload,               :proc   ],
      [ :before_reload,               :object ],
      [ :before_reload,               :block  ],
      [ :after_reload,                :method ],
      [ :after_reload,                :proc   ],
      [ :after_reload,                :object ],
      [ :after_reload,                :block  ]
    ], developer.history
  end

  def test_reload_singleton
    weather = Weather.find
    weather.reload
    assert_equal [
      [ :before_reload,               :method ],
      [ :before_reload,               :proc   ],
      [ :before_reload,               :object ],
      [ :before_reload,               :block  ],
      [ :after_reload,                :method ],
      [ :after_reload,                :proc   ],
      [ :after_reload,                :object ],
      [ :after_reload,                :block  ]
    ], weather.history
  end

  def test_update
    developer = Developer.find(1)
    developer.save
    assert_equal [
      [ :before_validation,           :method ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :after_validation,            :method ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
      [ :before_save,                 :method ],
      [ :before_save,                 :proc   ],
      [ :before_save,                 :object ],
      [ :before_save,                 :block  ],
      [ :before_update,               :method ],
      [ :before_update,               :proc   ],
      [ :before_update,               :object ],
      [ :before_update,               :block  ],
      [ :after_update,                :method ],
      [ :after_update,                :proc   ],
      [ :after_update,                :object ],
      [ :after_update,                :block  ],
      [ :after_save,                  :method ],
      [ :after_save,                  :proc   ],
      [ :after_save,                  :object ],
      [ :after_save,                  :block  ]
    ], developer.history
  end

  def test_update_singleton
    weather = Weather.find
    weather.save
    assert_equal [
      [ :before_validation,           :method ],
      [ :before_validation,           :proc   ],
      [ :before_validation,           :object ],
      [ :before_validation,           :block  ],
      [ :after_validation,            :method ],
      [ :after_validation,            :proc   ],
      [ :after_validation,            :object ],
      [ :after_validation,            :block  ],
      [ :before_save,                 :method ],
      [ :before_save,                 :proc   ],
      [ :before_save,                 :object ],
      [ :before_save,                 :block  ],
      [ :before_update,               :method ],
      [ :before_update,               :proc   ],
      [ :before_update,               :object ],
      [ :before_update,               :block  ],
      [ :after_update,                :method ],
      [ :after_update,                :proc   ],
      [ :after_update,                :object ],
      [ :after_update,                :block  ],
      [ :after_save,                  :method ],
      [ :after_save,                  :proc   ],
      [ :after_save,                  :object ],
      [ :after_save,                  :block  ]
    ], weather.history
  end

  def test_destroy
    developer = Developer.find(1)
    developer.destroy
    assert_equal [
      [ :before_destroy,              :method ],
      [ :before_destroy,              :proc   ],
      [ :before_destroy,              :object ],
      [ :before_destroy,              :block  ],
      [ :after_destroy,               :method ],
      [ :after_destroy,               :proc   ],
      [ :after_destroy,               :object ],
      [ :after_destroy,               :block  ]
    ], developer.history
  end

  def test_destroy_singleton
    weather = Weather.find
    weather.destroy
    assert_equal [
      [ :before_destroy,              :method ],
      [ :before_destroy,              :proc   ],
      [ :before_destroy,              :object ],
      [ :before_destroy,              :block  ],
      [ :after_destroy,               :method ],
      [ :after_destroy,               :proc   ],
      [ :after_destroy,               :object ],
      [ :after_destroy,               :block  ]
    ], weather.history
  end

  def test_delete
    developer = Developer.find(1)
    Developer.delete(developer.id)
    assert_equal [], developer.history
  end
end
