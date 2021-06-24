# frozen_string_literal: true

module Blog
  class ApplicationResource < ActiveResource::Base
    self.site = "https://jsonplaceholder.typicode.com/"
    self.include_format_in_path = false
  end

  class Post < ApplicationResource
    has_many :comments
  end

  class Comment < ApplicationResource
    belongs_to :post
  end
end
