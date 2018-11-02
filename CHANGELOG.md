## Active Resource 5.1.0 (Nov 2, 2018) ##

*   Improve support of Active Resource objects inside fibers.

*   Add support to Active Model Serializers.

*   Fix error when trying to parse `nil` as a JSON response.

*   Fix `exists?` to return the right value when the response code is between 200 and 206.

*   Match the log level to the HTTP response code.

*   Add `ActiveResource::Connection.logger` accessors to configure a specific logger instance for the
    connection object.

*   Add `ActiveResource::Base#element_url` method.

*   Add Active Job serialization support with Rails 6.

*   Support lazy setting of configuration options.

*   Use `UnnamedResource` when resource fails to create normally.

*   Add support to Bearer Token Authorization header to connection.

## Active Resource 5.0.0 (May 4, 2017) ##

*   Add `ActiveResource::Base.create!`.

*   Move observers support to rails-observers gem.

*   Remove support to Rails 4.

*   Remove support to Ruby 1.9, 2.0 and 2.1.

*   Fix `options[:class_name]` to keep the given class name, and not transform it to singular.
    Example:

    ```ruby
    has_one :profile_data, class_name: 'profile_data' #will correctly use ProfileData, and not ProfileDatum
    ```

*   `find_every` returns `[]`, not `nil`, when no records are found.

Please check [4-stable](https://github.com/rails/activeresource/blob/4-stable/CHANGELOG.md) for previous changes.
