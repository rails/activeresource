# frozen_string_literal: true

require "active_resource"
require "rails"

module ActiveResource
  class Railtie < Rails::Railtie
    config.active_resource = ActiveSupport::OrderedOptions.new

    initializer "active_resource.set_configs" do |app|
      ActiveSupport.on_load(:active_resource) do
        app.config.active_resource.each do |k, v|
          send "#{k}=", v
        end
      end
    end

    initializer "active_resource.add_active_job_serializer" do |app|
      if defined? app.config.active_job.custom_serializers
        require "active_resource/active_job_serializer"
        app.config.active_job.custom_serializers << ActiveResource::ActiveJobSerializer
      end
    end
  end
end
