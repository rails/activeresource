# frozen_string_literal: true

class Inventory < ActiveResource::Base
  include ActiveResource::Singleton
  self.site = "http://37s.sunrise.i:3000"
  self.prefix = "/products/:product_id/"

  schema do
    integer :total
    integer :used

    string :status
  end
end
