# frozen_string_literal: true

module ActiveResource
  class LogSubscriber < ActiveSupport::LogSubscriber
    def request(event)
      result = event.payload[:result]

      # When result is nil, the connection could not even be initiated
      # with the server, so we log an internal synthetic error response (523).
      code    = result.try(:code)    || 523  # matches CloudFlare's convention
      message = result.try(:message) || "ActiveResource connection error"
      body    = result.try(:body)    || ""

      log_level_method = code.to_i < 400 ? :info : :error

      send log_level_method, "#{event.payload[:method].to_s.upcase} #{event.payload[:request_uri]}"
      send log_level_method, "--> %d %s %d (%.1fms)" % [code, message, body.to_s.length, event.duration]
    end

    def logger
      ActiveResource::Base.logger
    end
  end
end

ActiveResource::LogSubscriber.attach_to :active_resource
