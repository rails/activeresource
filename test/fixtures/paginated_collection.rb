# frozen_string_literal: true

class PaginatedCollection < ActiveResource::Collection
  attr_accessor :next_page
  def initialize(parsed = {})
    @elements = parsed["results"]
    @next_page = parsed["next_page"]
  end
end
