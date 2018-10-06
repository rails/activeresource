class Comment < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000/api/v3/posts/:post_id"
end
