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

module Camelcase
  class Person < ::Person
    def load(attributes, *args)
      attributes = attributes.deep_transform_keys { |key| key.to_s.underscore }

      super
    end

    def serializable_hash(options = {})
      super.deep_transform_keys! { |key| key.camelcase(:lower) }
    end
  end
end
