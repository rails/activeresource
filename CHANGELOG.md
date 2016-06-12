
*   Remove support to Rails 4.

*   Remove support to Ruby 1.9, 2.0 and 2.1.

*   Fix `options[:class_name]` to keep the given class name, and not transform it to singular.
    Example:

    ```ruby
    has_one :profile_data, class_name: 'profile_data' #will correctly use ProfileData, and not ProfileDatum
    ```

*   `find_every` returns `[]`, not `nil`, when no records are found.

Please check [4-stable](https://github.com/rails/activeresource/blob/4-stable/CHANGELOG.md) for previous changes.
