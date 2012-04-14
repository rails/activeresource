class Comment < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000/posts/:post_id"
end
