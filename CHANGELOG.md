*   Remove Validations deprecation code

    Remove deprecation warnings when handling error response payloads that
    resemble the following:

    ```json
    {"errors":["First cannot be empty"]}

    {"first":["cannot be empty"]}
    ```

    *Sean Doyle*

*   Support `.serialize …, coder: …` for Collections

    ```ruby
    class Person < ActiveResource::Base
      # …
    end

    class Team < ApplicationRecord
      serialize :people, coder: Person.collection_coder
    end
    ```

    *Sean Doyle*

*   Introduce `Base.query_format` for URL encoding values

    ```ruby
    class CamelcaseUrlEncodedFormat
      include ActiveResource::Formats::UrlEncodedFormat

      def encode(params, options = nil)
        params = params.deep_transform { |key| key.to_s.camelcase(:lower) }

        super
      end
    end

    class Person < ActiveResource::Base
      self.site = "https://example.com"
      self.query_format = CamelcaseUrlEncodedFormat.new
    end

    Person.where(first_name: "Sean")
    # => GET https://example.com/people.json?firstName=Sean
    ```

    *Sean Doyle*

*   Raise `ActiveResource::UnavailableForLegalReasons` for HTTP 451

    *Sean Doyle*

*   `Coder#load`: Conditionally call `Formats.remove_root`

    To resolve the `@persisted` value, call `Format.remove_root` to ensure
    that the payload consists of only attributes.

    *Sean Doyle*

*   `ActiveResource::Singleton::CustomMethods` module to use `singleton_name` in path

    ```ruby
    class Inventory < ActiveResource::Base
      include ActiveResource::Singleton
    end

    # BEFORE
    inventory = Inventory.find(params: { product_id: 1 })   # => GET /products/1/inventory.json

    inventory.get(:report, product_id: 1)                   # => GET /products/1/inventories/report.json
    inventory.delete(:reset, product_id: 1)                 # => DELETE /products/1/inventories/reset.json

    Inventory.get(:report, product_id: 1)                   # => GET /products/1/inventories/report.json
    Inventory.delete(:reset, product_id: 1)                 # => DELETE /products/1/inventories/reset.json

    # AFTER
    Inventory.include ActiveResource::Singleton::CustomMethods

    Inventory.get(:report, product_id: 1)                   # => GET /products/1/inventory/report.json
    Inventory.delete(:reset, product_id: 1)                 # => DELETE /products/1/inventory/reset.json
    inventory = Inventory.find(params: { product_id: 1 })   # => GET /products/1/inventory.json

    inventory.get(:report)                                  # => GET /products/1/inventory/report.json
    inventory.delete(:reset)                                # => DELETE /products/1/inventory/reset.json
    ```

    *Sean Doyle*

*   Implement `Base#encode` in terms of `format.encode`

    ```ruby
    class CamelcaseJsonFormat
      include ActiveResource::Formats[:json]

      def encode(resource, options = nil)
        hash = resource.as_json(options)
        hash = hash.deep_transform_keys! { |key| key.camelcase(:lower) }
        super(hash)
      end

      def decode(json)
        hash = super
        hash.deep_transform_keys! { |key| key.underscore }
      end
    end

    Person.format = CamelcaseJsonFormat.new

    person = Person.new(first_name: "First", last_name: "Last")
    person.encode
    # => "{\"person\":{\"firstName\":\"First\",\"lastName\":\"Last\"}}"

    Person.format.decode(person.encode)
    # => {"first_name"=>"First", "last_name"=>"Last"}
    ```

    *Sean Doyle*

*   Add reload callbacks

    ```ruby
    class User < ActiveResource::Base
      before_reload -> { throw :abort }, unless: :id?
      after_reload -> { Rails.logger.info("Congratulations, the callback has run!") }
      around_reload :log_reloading

      schema do
        attribute :email, :string
      end

      def log_reloading
        Rails.logger.info("Reloading user with email: #{email}")
        yield
        Rails.logger.info("User reloaded with email: #{email}")
      end
    end
    ```

    *Sean Doyle*

Please check [v6.2.0](https://github.com/rails/activeresource/releases/tag/v6.2.0) for previous changes.
