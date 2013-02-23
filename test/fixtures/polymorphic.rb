class Employee < ActiveResource::Base
  self.site = "http://localhost:3000"
end

class Quality < ActiveResource::Base
  self.site = "http://localhost:3000"
end

class Mood < ActiveResource::Base
  self.site = "http://localhost:3000"
end

class Boss < Employee
  has_one :mood
  has_many :qualities
end

class Quality < ActiveResource::Base
  belongs_to :employee
end

class Mood < ActiveResource::Base
  belongs_to :employee
end

class Quality < ActiveResource::Base
  belongs_to :employee
end

class GoodQuality < Quality
end

class BadQuality < Quality
end

class GoodMood < Mood
end