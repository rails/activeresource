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
      if app.config.try(:active_job).try(:custom_serializers)
        require "active_resource/active_job_serializer"
        app.config.active_job.custom_serializers << ActiveResource::ActiveJobSerializer
      end
    end

    initializer "active_resource.deprecator" do |app|
      if app.respond_to?(:deprecators)
        app.deprecators[:active_resource] = ActiveResource.deprecator
      end
    end
  end
end
