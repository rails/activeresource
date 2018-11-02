# frozen_string_literal: true

class Person < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
end

module External
  class Person < ActiveResource::Base
    self.site = "http://atq.caffeine.intoxication.it"
  end

  class ProfileData < ActiveResource::Base
    self.site = "http://external.profile.data.nl"
  end
end
