# frozen_string_literal: true

require "abstract_unit"

require "fixtures/project"
require "fixtures/person"
require "fixtures/product"
require "active_job"
require "active_job/arguments"
require "active_resource/active_job_serializer"

class ActiveJobSerializerTest < ActiveSupport::TestCase
  setup do
    @klass = ActiveResource::ActiveJobSerializer
  end

  def test_serialize
    project = Project.new(id: 1, name: "Ruby on Rails")
    project.prefix_options[:person_id] = 1
    project_json = {
      _aj_serialized: @klass.name,
      class: project.class.name,
      persisted: project.persisted?,
      prefix_options: project.prefix_options,
      attributes: project.attributes
    }.as_json
    serialized_json = @klass.serialize(project)

    assert_equal project_json, serialized_json
  end

  def test_deserialize
    person = Person.new(id: 2, name: "David")
    person.persisted = true
    person_json = {
      _aj_serialized: @klass.name,
      class: person.class.name,
      persisted: person.persisted?,
      prefix_options: person.prefix_options,
      attributes: person.attributes
    }.as_json
    deserialized_object = @klass.deserialize(person_json)

    assert_equal person, deserialized_object
  end

  def test_serialize?
    product = Product.new(id: 3, name: "Chunky Bacon")

    assert @klass.serialize?(product)
    assert_not @klass.serialize?("not a resource")
  end
end
