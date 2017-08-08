module ActiveResource
  class LogSubscriber < ActiveSupport::LogSubscriber
    def request(event)
      result = event.payload[:result]

      log_level_method = result.code.to_i < 400 ? :info : :error

      send log_level_method, "#{event.payload[:method].to_s.upcase} #{event.payload[:request_uri]}"
      send log_level_method, "--> %d %s %d (%.1fms)" % [result.code, result.message, result.body.to_s.length, event.duration]
    end

    def logger
      ActiveResource::Base.logger
    end
  end
end

ActiveResource::LogSubscriber.attach_to :active_resource
