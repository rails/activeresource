module CustomPath
  class Post < ActiveResource::Base
    self.site = "http://37s.sunrise.i:3000/custom/path"
  end

  class Person < ActiveResource::Base
    self.site = "http://37s.sunrise.i:3000/custom/path"
  end

  class Comment < ActiveResource::Base
    self.site = "http://37s.sunrise.i:3000/custom/path/posts/:post_id"
  end
end
