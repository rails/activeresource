# frozen_string_literal: true

class Product < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  # X-Inherited-Header is for testing that any subclasses
  # include the headers of this class
  self.headers["X-Inherited-Header"] = "present"
end

class SubProduct < Product
end
