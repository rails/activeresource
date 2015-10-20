class Device < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  self.element_name = 'device'

  self.except_primary_key = true
  update_except :code
end
