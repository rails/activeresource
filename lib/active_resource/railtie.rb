require "active_resource"
require "rails"

module ActiveResource
  class Railtie < Rails::Railtie
    config.active_resource = ActiveSupport::OrderedOptions.new

    initializer "active_resource.set_configs" do |app|
      app.config.active_resource.each do |k,v|
        ActiveResource::Base.send "#{k}=", v
      end
    end

    config.after_initialize do |app|
      ActiveSupport.on_load(:active_resource) do
        ActiveResource::Base.instantiate_observers

        ActionDispatch::Reloader.to_prepare do
          ActiveResource::Base.instantiate_observers
        end
      end
    end
  end
end

