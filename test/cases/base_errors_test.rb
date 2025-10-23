# frozen_string_literal: true

require "abstract_unit"
require "fixtures/person"

class BaseErrorsTest < ActiveSupport::TestCase
  def setup
    ActiveResource::HttpMock.respond_to do |mock|
      mock.post "/people.xml", {}, %q(<?xml version="1.0" encoding="UTF-8"?><errors><error>Age can't be blank</error><error>Known attribute can't be blank</error><error>Name can't be blank</error><error>Name must start with a letter</error><error>Person quota full for today.</error><error>Phone work can't be blank</error><error>Phone is not valid</error></errors>), 422, "Content-Type" => "application/xml; charset=utf-8"
      mock.post "/people.json", {}, %q({"errors":{"age":["can't be blank"],"known_attribute":["can't be blank"],"name":["can't be blank", "must start with a letter"],"person":["quota full for today."],"phone_work":["can't be blank"],"phone":["is not valid"]}}), 422, "Content-Type" => "application/json; charset=utf-8"
    end
  end

  def test_should_mark_as_invalid
    [ :json, :xml ].each do |format|
      invalid_user_using_format(format) do
        assert_not @person.valid?
      end
    end
  end

  def test_should_parse_json_and_xml_errors
    [ :json, :xml ].each do |format|
      invalid_user_using_format(format) do
        assert_kind_of ActiveResource::Errors, @person.errors
        assert_equal 7, @person.errors.size
      end
    end
  end

  def test_should_parse_json_errors_when_no_errors_key
    ActiveResource::HttpMock.respond_to do |mock|
      mock.post "/people.json", {}, "{}", 422, "Content-Type" => "application/json; charset=utf-8"
    end

    invalid_user_using_format(:json) do
      assert_kind_of ActiveResource::Errors, @person.errors
      assert_equal 0, @person.errors.size
    end
  end

  def test_should_parse_errors_to_individual_attributes
    [ :json, :xml ].each do |format|
      invalid_user_using_format(format) do
        assert @person.errors[:name].any?
        assert_equal [ "can't be blank" ], @person.errors[:age]
        assert_equal [ "can't be blank", "must start with a letter" ], @person.errors[:name]
        assert_equal [ "can't be blank" ], @person.errors[:phone_work]
        assert_equal [ "is not valid" ], @person.errors[:phone]
        assert_equal [ "Person quota full for today." ], @person.errors[:base]
      end
    end
  end

  def test_should_parse_errors_to_known_attributes
    [ :json, :xml ].each do |format|
      invalid_user_using_format(format) do
        assert_equal [ "can't be blank" ], @person.errors[:known_attribute]
      end
    end
  end

  def test_should_iterate_over_errors
    [ :json, :xml ].each do |format|
      invalid_user_using_format(format) do
        errors = []
        if ActiveSupport.gem_version >= Gem::Version.new("6.1.x")
          @person.errors.each { |error| errors << [ error.attribute, error.message ] }
        else
          @person.errors.each { |attribute, message| errors << [ attribute, message ] }
        end
        assert errors.include?([ :name, "can't be blank" ])
      end
    end
  end

  def test_should_iterate_over_full_errors
    [ :json, :xml ].each do |format|
      invalid_user_using_format(format) do
        errors = []
        @person.errors.to_a.each { |message| errors << message }
        assert errors.include?("Name can't be blank")
      end
    end
  end

  def test_should_format_full_errors
    [ :json, :xml ].each do |format|
      invalid_user_using_format(format) do
        full = @person.errors.full_messages
        assert full.include?("Age can't be blank")
        assert full.include?("Name can't be blank")
        assert full.include?("Name must start with a letter")
        assert full.include?("Person quota full for today.")
        assert full.include?("Phone is not valid")
        assert full.include?("Phone work can't be blank")
      end
    end
  end

  def test_should_mark_as_invalid_when_content_type_is_unavailable_in_response_header
    ActiveResource::HttpMock.respond_to do |mock|
      mock.post "/people.xml", {}, %q(<?xml version="1.0" encoding="UTF-8"?><errors><error>Age can't be blank</error><error>Name can't be blank</error><error>Name must start with a letter</error><error>Person quota full for today.</error><error>Phone work can't be blank</error><error>Phone is not valid</error></errors>), 422, {}
      mock.post "/people.json", {}, %q({"errors":{"age":["can't be blank"],"name":["can't be blank", "must start with a letter"],"person":["quota full for today."],"phone_work":["can't be blank"],"phone":["is not valid"]}}), 422, {}
    end

    [ :json, :xml ].each do |format|
      invalid_user_using_format(format) do
        assert_not @person.valid?
      end
    end
  end

  def test_rescues_from_configured_exception_class_name
    ActiveResource::HttpMock.respond_to do |mock|
      mock.post "/people.xml", {}, %q(<?xml version="1.0" encoding="UTF-8"?><errors><error>Age can't be blank</error></errors>), 400, {}
      mock.post "/people.json", {}, %q({"errors":{"age":["can't be blank"]}}), 400, {}
    end

    [ :json, :xml ].each do |format|
      invalid_user_using_format(format, rescue_from: "ActiveResource::BadRequest") do
        assert_not_predicate @person, :valid?
        assert_equal [ "can't be blank" ], @person.errors[:age]
      end
    end
  end

  def test_rescues_from_configured_array_of_exception_classes
    [ :json, :xml ].product([ 400, 422 ]).each do |format, error_status|
      ActiveResource::HttpMock.respond_to do |mock|
        mock.post "/people.xml", {}, %q(<?xml version="1.0" encoding="UTF-8"?><errors><error>Age can't be blank</error></errors>), error_status, {}
        mock.post "/people.json", {}, %q({"errors":{"age":["can't be blank"]}}), error_status, {}
      end

      invalid_user_using_format(format, rescue_from: [ ActiveResource::BadRequest, ActiveResource::ResourceInvalid ]) do
        assert_not_predicate @person, :valid?
        assert_equal [ "can't be blank" ], @person.errors[:age]
      end
    end
  end

  private
    def invalid_user_using_format(mime_type_reference, rescue_from: nil)
      previous_format = Person.format
      previous_schema = Person.schema
      previous_remote_errors = Person.remote_errors

      Person.format = mime_type_reference
      Person.schema = { "known_attribute" => "string" }
      Person.remote_errors = rescue_from
      @person = Person.new(name: "", age: "", phone: "", phone_work: "")
      assert_equal false, @person.save

      yield
    ensure
      Person.format = previous_format
      Person.schema = previous_schema
      Person.remote_errors = previous_remote_errors
    end
end
