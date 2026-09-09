# frozen_string_literal: true

require "abstract_unit"
require "fixtures/person"

class DirtyTest < ActiveSupport::TestCase
  setup do
    setup_response
    @previous_schema = Person.schema
  end

  teardown do
    Person.schema = @previous_schema
  end

  test "is clean when built" do
    resource = Person.new

    assert_empty resource.changes
  end

  test "is clean when reloaded" do
    Person.schema do
      attribute :name, :string
    end

    resource = Person.find(1)
    resource.name = "changed"

    assert_changes -> { resource.name_changed? }, from: true, to: false do
      resource.reload
    end
  end

  test "is clean after create" do
    Person.schema do
      attribute :name, :string
    end

    resource = Person.new name: "changed"
    ActiveResource::HttpMock.respond_to.post "/people.json", {}, { id: 1, name: "changed" }.to_json

    assert_changes -> { resource.name_changed? }, from: true, to: false do
      resource.save
    end
    assert_empty resource.changes
  end

  test "is clean after update" do
    Person.schema do
      attribute :name, :string
    end

    resource = Person.find(1)
    ActiveResource::HttpMock.respond_to.put "/people/1.json", {}, { id: 1, name: "changed" }.to_json

    assert_changes -> { resource.name_changed? }, from: true, to: false do
      resource.update(name: "changed")
    end
    assert_empty resource.changes
  end

  test "is dirty when known attribute changes are unsaved" do
    Person.schema do
      attribute :name, :string
    end
    expected_changes = {
      "name" => [ nil, "known" ]
    }

    resource = Person.new name: "known"

    assert_predicate resource, :name_changed?
    assert_equal expected_changes, resource.changes
  end

  test "is not dirty when unknown attribute changes are unsaved" do
    resource = Person.new name: "unknown"

    assert_not_predicate resource, :name_changed?
    assert_empty resource.changes
  end
end
