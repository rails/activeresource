# frozen_string_literal: true

require "abstract_unit"
require "fixtures/project"
require "active_support/core_ext/hash/conversions"

# The validations are tested thoroughly under ActiveModel::Validations
# This test case simply makes sure that they are all accessible by
# Active Resource objects.
class ValidationsTest < ActiveSupport::TestCase
  VALID_PROJECT_HASH = { name: "My Project", description: "A project" }
  def setup
    @my_proj = { "person" => VALID_PROJECT_HASH }.to_json
    ActiveResource::HttpMock.respond_to do |mock|
      mock.post "/projects.json", {}, @my_proj, 201, "Location" => "/projects/5.json"
    end
  end

  def test_validates_presence_of
    p = new_project(name: nil)
    assert_not p.valid?, "should not be a valid record without name"
    assert_not p.save, "should not have saved an invalid record"
    assert_equal [ "can't be blank" ], p.errors[:name], "should have an error on name"

    p.name = "something"

    assert p.save, "should have saved after fixing the validation, but had: #{p.errors.inspect}"
  end

  def test_fails_save!
    p = new_project(name: nil)
    assert_raise(ActiveResource::ResourceInvalid) { p.save! }
  end

  def test_save_without_validation
    p = new_project(name: nil)
    assert_not p.save
    assert p.save(validate: false)
  end

  def test_validate_callback
    # we have a callback ensuring the description is longer than three letters
    p = new_project(description: "a")
    assert_not p.valid?, "should not be a valid record when it fails a validation callback"
    assert_not p.save, "should not have saved an invalid record"
    assert_equal [ "must be greater than three letters long" ], p.errors[:description], "should be an error on description"

    # should now allow this description
    p.description = "abcd"
    assert p.save, "should have saved after fixing the validation, but had: #{p.errors.inspect}"
  end

  def test_client_side_validation_maximum
    project = Project.new(description: "123456789012345")
    assert_not project.valid?
    assert_equal [ "is too long (maximum is 10 characters)" ], project.errors[:description]
  end

  def test_invalid_method
    p = new_project

    assert_not p.invalid?
  end

  def test_validate_bang_method
    p = new_project(name: nil)

    assert_raise(ActiveModel::ValidationError) { p.validate! }
  end

  protected
    # quickie helper to create a new project with all the required
    # attributes.
    # Pass in any params you specifically want to override
    def new_project(opts = {})
      Project.new(VALID_PROJECT_HASH.merge(opts))
    end
end

class ErrorsTest < ActiveSupport::TestCase
  def test_from_xml_with_multiple_errors
    errors = Project.new.errors

    errors.from_xml %q(<?xml version="1.0" encoding="UTF-8"?><errors><error>Name can't be blank</error><error>Email can't be blank</error></errors>)

    assert_equal [ "can't be blank" ], errors[:name]
    assert_equal [ "can't be blank" ], errors[:email]
  end

  def test_from_xml_with_one_error
    errors = Project.new.errors

    errors.from_xml %q(<?xml version="1.0" encoding="UTF-8"?><errors><error>Name can't be blank</error></errors>)

    assert_equal [ "can't be blank" ], errors[:name]
  end

  def test_from_json
    errors = Project.new.errors

    errors.from_json %q({"errors":{"name":["can't be blank"],"email":["can't be blank"]}})

    assert_equal [ "can't be blank" ], errors[:name]
    assert_equal [ "can't be blank" ], errors[:email]
  end

  def test_from_hash
    errors = Project.new.errors

    errors.from_hash(
      "base" => [ "has an error" ],
      "unknown" => [ "is invalid" ],
      "name" => [ "can't be blank" ],
      "email" => [ "can't be blank" ]
    )

    assert_equal [ "has an error", "Unknown is invalid" ], errors[:base]
    assert_equal [ "can't be blank" ], errors[:name]
    assert_equal [ "can't be blank" ], errors[:email]
  end

  def test_from_array
    errors = Project.new.errors

    errors.from_array [
      "Unknown is invalid",
      "Base has an error",
      "Name can't be blank",
      "Email can't be blank"
    ]

    assert_equal [ "Unknown is invalid", "Base has an error" ], errors[:base]
    assert_equal [ "can't be blank" ], errors[:name]
    assert_equal [ "can't be blank" ], errors[:email]
  end
end
