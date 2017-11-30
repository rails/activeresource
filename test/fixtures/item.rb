class Item < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  self.find_method = '/detail'
end
