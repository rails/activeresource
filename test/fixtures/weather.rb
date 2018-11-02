# frozen_string_literal: true

class Weather < ActiveResource::Base
  include ActiveResource::Singleton
  self.site = "http://37s.sunrise.i:3000"

  schema do
    string  :status
    string  :temperature
  end
end

class WeatherDashboard < ActiveResource::Base
  include ActiveResource::Singleton
  self.site = "http://37s.sunrise.i:3000"
  self.singleton_name = "dashboard"

  schema do
    string :status
  end
end
