# frozen_string_literal: true

class Pet < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  self.prefix = "/people/:person_id/"
end
