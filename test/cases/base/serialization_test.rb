# frozen_string_literal: true

require "abstract_unit"
require "fixtures/person"
require "fixtures/paginated_collection"

require "active_record"

ENV["DATABASE_URL"] = "sqlite3::memory:"

ActiveRecord::Base.establish_connection

ActiveRecord::Schema.define do
  create_table :teams, force: true do |t|
    t.text :people_text
    t.text :paginated_people_text
    t.json :people_json
    t.json :paginated_people_json

    t.check_constraint <<~SQL, name: "people_json_is_object"
      JSON_TYPE(people_json) = 'array'
    SQL
    t.check_constraint <<~SQL, name: "paginated_people_json_is_object"
      JSON_TYPE(paginated_people_json) = 'object'
    SQL
  end
end

class PaginatedPerson < Person
  self.collection_parser = "PaginatedCollection"
end

class Team < ActiveRecord::Base
  if ActiveSupport::VERSION::MAJOR < 8 && ActiveSupport::VERSION::MINOR < 1
    serialize :people_text, Person.collection_coder
    serialize :people_json, ActiveResource::Coder.new(Person, :original_parsed, collection: true)

    serialize :paginated_people_text, PaginatedPerson.collection_coder
    serialize :paginated_people_json, ActiveResource::Coder.new(PaginatedPerson, :original_parsed, collection: true)
  else
    serialize :people_text, coder: Person.collection_coder
    serialize :people_json, coder: ActiveResource::Coder.new(Person, :original_parsed, collection: true)

    serialize :paginated_people_text, coder: PaginatedPerson.collection_coder
    serialize :paginated_people_json, coder: ActiveResource::Coder.new(PaginatedPerson, :original_parsed, collection: true)
  end
end

require "active_record"

ENV["DATABASE_URL"] = "sqlite3::memory:"

ActiveRecord::Base.establish_connection

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.text :person_text
    t.json :person_json

    t.check_constraint <<~SQL, name: "person_json_is_object"
      JSON_TYPE(person_json) = 'object'
    SQL
  end

  create_table :teams, force: true do |t|
    t.text :people_text
    t.text :paginated_people_text
    t.json :people_json
    t.json :paginated_people_json

    t.check_constraint <<~SQL, name: "people_json_is_object"
      JSON_TYPE(people_json) = 'array'
    SQL
    t.check_constraint <<~SQL, name: "paginated_people_json_is_object"
      JSON_TYPE(paginated_people_json) = 'object'
    SQL
  end
end

class User < ActiveRecord::Base
  if ActiveSupport::VERSION::MAJOR < 8 && ActiveSupport::VERSION::MINOR < 1
    serialize :person_text, Person
    serialize :person_json, ActiveResource::Coder.new(Person, :serializable_hash)
  else
    serialize :person_text, coder: Person
    serialize :person_json, coder: ActiveResource::Coder.new(Person, :serializable_hash)
  end
end

class SerializationTest < ActiveSupport::TestCase
  include ActiveRecord::TestFixtures

  test "dumps to a text column" do
    resource = Person.new({ id: 1, name: "Matz" }, true)

    User.create!(person_text: resource)

    user = User.sole
    assert_equal resource.to_json, user.person_text_before_type_cast
  end

  test "dumps to a json column" do
    resource = Person.new({ id: 1, name: "Matz" }, true)

    User.create!(person_json: resource)

    user = User.sole
    assert_equal resource.serializable_hash.to_json, user.person_json_before_type_cast
  end

  test "loads from a text column" do
    resource = Person.new(id: 1, name: "Matz")

    User.connection.execute(<<~SQL)
      INSERT INTO users(person_text)
      VALUES ('#{resource.encode}')
    SQL

    user = User.sole
    assert_predicate user.person_text, :persisted?
    assert_equal resource, user.person_text
    assert_equal resource.attributes, user.person_text.attributes
  end

  test "loads from a json column" do
    resource = Person.new(id: 1, name: "Matz")

    User.connection.execute(<<~SQL)
      INSERT INTO users(person_json)
      VALUES ('#{resource.encode}')
    SQL

    user = User.sole
    assert_predicate user.person_json, :persisted?
    assert_equal resource, user.person_json
    assert_equal resource.attributes, user.person_json.attributes
  end
  test ".load delegates to the .coder" do
    resource = Person.new(id: 1, name: "Matz")

    encoded = Person.load(resource.encode)

    assert_equal resource.id, encoded.id
    assert_equal resource.name, encoded.name
    assert_equal resource.attributes, encoded.attributes
  end

  test ".load decodes JSON" do
    previous_value, Person.format = Person.format, :json

    resource = Person.new(id: 1, name: "Matz")
    json = resource.to_json

    assert_equal resource, Person.load(json)
  ensure
    Person.format = previous_value
  end

  test ".load decodes XML" do
    previous_value, Person.format = Person.format, :xml

    resource = Person.new(id: 1, name: "Matz")
    xml = resource.to_xml

    assert_equal resource, Person.load(xml)
  ensure
    Person.format = previous_value
  end

  test ".dump delegates to the default .coder" do
    resource = Person.new(id: 1, name: "Matz")

    encoded = Person.dump(resource)

    assert_equal resource.encode, encoded
    assert_equal({ person: { id: 1, name: "Matz" } }.to_json, encoded)
  end

  test ".dump delegates to a configured .coder method name" do
    previous_value, Person.coder = Person.coder, ActiveResource::Coder.new(Person, :serializable_hash)

    resource = Person.new(id: 1, name: "Matz")

    assert_equal resource.serializable_hash, Person.dump(resource)
  ensure
    Person.coder = previous_value
  end

  test ".dump delegates to a configured .coder callable" do
    previous_value, Person.coder = Person.coder, ActiveResource::Coder.new(Person) { |value| value.serializable_hash }

    resource = Person.new(id: 1, name: "Matz")

    assert_equal resource.serializable_hash, Person.dump(resource)
  ensure
    Person.coder = previous_value
  end

  test ".dump encodes JSON" do
    previous_value, Person.format = Person.format, :json

    resource = Person.new(id: 1, name: "Matz")

    assert_equal resource.to_json, Person.dump(resource)
  ensure
    Person.format = previous_value
  end

  test ".dump encodes XML" do
    previous_value, Person.format = Person.format, :xml

    resource = Person.new(id: 1, name: "Matz")

    assert_equal resource.to_xml, Person.dump(resource)
  ensure
    Person.format = previous_value
  end

  test "#load returns nil when the encoded value is nil" do
    assert_nil Person.coder.load(nil)
  end

  test "#load decodes a String into an instance" do
    resource = Person.new(id: 1, name: "Matz")

    decoded = Person.coder.load(resource.encode)

    assert_equal resource, decoded
  end

  test "#load decodes a Hash into an instance" do
    resource = Person.new(id: 1, name: "Matz")

    decoded = Person.coder.load(JSON.parse(resource.encode))

    assert_equal resource.id, decoded.id
    assert_equal resource.name, decoded.name
    assert_equal resource.attributes, decoded.attributes
  end

  test "#load builds the instance as persisted when the default primary key is present" do
    resource = Person.new(id: 1, name: "Matz")

    [ resource.encode, JSON.parse(resource.encode) ].each do |encoded|
      decoded = Person.coder.load(encoded)

      assert_predicate decoded, :persisted?
      assert_not_predicate decoded, :new_record?
    end
  end

  test "#load builds the instance as persisted when the configured primary key is present" do
    previous_value, Person.primary_key = Person.primary_key, "pk"
    resource = Person.new(pk: 1, name: "Matz")

    [ resource.encode, JSON.parse(resource.encode) ].each do |encoded|
      decoded = Person.coder.load(encoded)

      assert_equal 1, decoded.id
      assert_predicate decoded, :persisted?
      assert_not_predicate decoded, :new_record?
    end
  ensure
    Person.primary_key = previous_value
  end

  test "#load builds the instance as a new record when the default primary key is absent" do
    resource = Person.new(name: "Matz")

    [ resource.encode, JSON.parse(resource.encode) ].each do |encoded|
      decoded = Person.coder.load(encoded)

      assert_nil decoded.id
      assert_not_predicate decoded, :persisted?
      assert_predicate decoded, :new_record?
    end
  end

  test "#load builds the instance as a new record when the configured primary key is absent" do
    previous_value, Person.primary_key = Person.primary_key, "pk"
    resource = Person.new(name: "Matz")

    [ resource.encode, JSON.parse(resource.encode) ].each do |encoded|
      decoded = Person.coder.load(encoded)

      assert_nil decoded.id
      assert_not_predicate decoded, :persisted?
      assert_predicate decoded, :new_record?
    end
  ensure
    Person.primary_key = previous_value
  end

  test "#load raises an ArgumentError when passed anything but a String or Hash" do
    resource = Person.new(name: "Matz")
    string_value = resource.encode
    hash_value = resource.attributes

    assert_equal resource, Person.coder.load(string_value)
    assert_equal resource, Person.coder.load(hash_value)
    assert_raises(ArgumentError, match: "expected value to be Hash, but was Integer") { Person.coder.load(1) }
  end

  test "#load does not remove a non-root key from a single-key Hash" do
    payload = { "friends" => [ { "id" => 1 } ] }

    decoded = Person.coder.load(payload)

    assert_equal [ 1 ], decoded.friends.map(&:id)
  end

  test "#dump encodes resources" do
    resource = Person.new(id: 1, name: "Matz")

    encoded = Person.coder.dump(resource)

    assert_equal resource.encode, encoded
    assert_equal({ person: { id: 1, name: "Matz" } }.to_json, encoded)
  end

  test "#dump raises an ArgumentError is passed anything but an ActiveResource::Base" do
    assert_raises ArgumentError, match: "expected value to be Person, but was Integer" do
      Person.coder.dump(1)
    end
  end

  test "#dump returns nil when the resource is nil" do
    assert_nil Person.coder.dump(nil)
  end

  test "#dump with an encoder method name returns nil when the resource is nil" do
    coder = ActiveResource::Coder.new(Person, :serializable_hash)

    assert_nil coder.dump(nil)
  end

  test "#dump with an encoder method name encodes resources" do
    coder = ActiveResource::Coder.new(Person, :serializable_hash)
    resource = Person.new(id: 1, name: "Matz")

    encoded = coder.dump(resource)

    assert_equal resource.serializable_hash, encoded
  end

  test "#dump with an encoder block encodes resources" do
    coder = ActiveResource::Coder.new(Person) { |value| value.serializable_hash }
    resource = Person.new(id: 1, name: "Matz")

    encoded = coder.dump(resource)

    assert_equal resource.serializable_hash, encoded
  end
end

class CollectionSerializationTest < ActiveSupport::TestCase
  include ActiveRecord::TestFixtures

  def setup
    @person = { "id" => 1, "title" => "Matz" }
    @people = [ @person ]
    @paginated_people = { "results" => [ @person ], "next_page" => "/paginated_people?page=2" }

    ActiveResource::HttpMock.respond_to do |mock|
      mock.get "/people", { "Accept" => "application/json" }, @people.to_json
      mock.get "/people", { "Accept" => "application/xml" }, @people.to_xml
      mock.get "/paginated_people", { "Accept" => "application/json" }, @paginated_people.to_json
      mock.get "/paginated_people", { "Accept" => "application/xml" }, @paginated_people.to_xml
    end

    ActiveResource::Base.include_format_in_path = false
  end

  def teardown
    ActiveResource::Base.include_format_in_path = true
  end

  test "dumps ActiveResource::Collection to a text column" do
    collection = Person.all

    team = Team.create!(people_text: collection)

    assert_equal collection.encode, team.people_text_before_type_cast
  end

  test "dumps ActiveResource::Collection to a json column" do
    collection = Person.all

    team = Team.create!(people_json: collection)

    assert_equal collection.encode, team.people_json_before_type_cast
  end

  test "dumps ActiveResource::Collection subclass to a text column" do
    collection = PaginatedPerson.all

    team = Team.create!(paginated_people_text: collection)

    assert_equal collection.encode, team.paginated_people_text_before_type_cast
    assert_equal @paginated_people["next_page"], team.paginated_people_text.next_page
  end

  test "dumps ActiveResource::Collection subclass to a json column" do
    collection = PaginatedPerson.all

    team = Team.create!(paginated_people_json: collection)

    assert_equal collection.encode, team.paginated_people_json_before_type_cast
    assert_equal @paginated_people["next_page"], team.paginated_people_json.next_page
  end

  test "loads ActiveResource::Collection from a text column" do
    collection = Person.all

    Team.connection.execute(<<~SQL)
      INSERT INTO teams(people_text)
      VALUES ('#{collection.encode}')
    SQL

    team = Team.sole
    assert team.people_text.all?(&:persisted?)
    assert_equal collection, team.people_text
    assert_equal @people, team.people_text.map(&:attributes)
  end

  test "loads ActiveResource::Collection from a json column" do
    collection = Person.all

    Team.connection.execute(<<~SQL)
      INSERT INTO teams(people_json)
      VALUES ('#{collection.encode}')
    SQL

    team = Team.sole
    assert team.people_json.all?(&:persisted?)
    assert_equal collection, team.people_json
    assert_equal @people, team.people_json.map(&:attributes)
  end

  test "loads ActiveResource::Collection subclass from a text column" do
    collection = PaginatedPerson.all

    Team.connection.execute(<<~SQL)
      INSERT INTO teams(paginated_people_text)
      VALUES ('#{collection.encode}')
    SQL

    team = Team.sole
    assert team.paginated_people_text.all?(&:persisted?)
    assert_equal collection, team.paginated_people_text
    assert_equal @paginated_people["results"], team.paginated_people_text.map(&:attributes)
    assert_equal @paginated_people["next_page"], team.paginated_people_text.next_page
  end

  test "loads ActiveResource::Collection subclass from a json column" do
    collection = PaginatedPerson.all

    Team.connection.execute(<<~SQL)
      INSERT INTO teams(paginated_people_json)
      VALUES ('#{collection.encode}')
    SQL

    team = Team.sole
    assert team.paginated_people_json.all?(&:persisted?)
    assert_equal collection, team.paginated_people_json
    assert_equal @paginated_people["results"], team.paginated_people_json.map(&:attributes)
    assert_equal @paginated_people["next_page"], team.paginated_people_json.next_page
  end

  test "#load decodes an Array collection into an instance" do
    [ :json, :xml ].each do |format|
      using_format Person, format do
        collection = Person.all

        decoded = Person.collection_coder.load(collection.encode)

        assert_equal @people, decoded.original_parsed
        assert_equal collection.to_a, decoded
        assert_equal collection.map(&:attributes), decoded.map(&:attributes)
      end
    end
  end

  test "#load decodes a Hash collection into an instance" do
    [ :json, :xml ].each do |format|
      using_format PaginatedPerson, format do
        collection = PaginatedPerson.all

        decoded = PaginatedPerson.collection_coder.load(collection.encode)

        assert_equal @paginated_people, decoded.original_parsed
        assert_equal collection.to_a, decoded
        assert_equal collection.map(&:attributes), decoded.map(&:attributes)
      end
    end
  end

  test "#load raises an ArgumentError when passed anything but a String or Hash" do
    assert_raises(ArgumentError, match: "expected value to be Hash or Array, but was Integer") { Person.collection_coder.load(1) }
  end

  test "#dump encodes an Array collection into a String" do
    [ :json, :xml ].each do |format|
      using_format Person, format do
        collection = Person.all

        encoded = Person.collection_coder.dump(collection)

        assert_equal collection.encode, encoded
        assert_equal @people.send("to_#{format}"), encoded
      end
    end
  end

  test "#dump encodes an Array collection with a custom encoder" do
    [ :json, :xml ].each do |format|
      using_format Person, format do
        coder = ActiveResource::Coder.new(Person, collection: true) { |value| value.map(&:serializable_hash) }
        collection = Person.all

        encoded = coder.dump(collection)

        assert_equal collection.map(&:serializable_hash), encoded
      end
    end
  end

  test "#dump encodes a Hash collection into a String" do
    [ :json, :xml ].each do |format|
      using_format PaginatedPerson, format do
        collection = PaginatedPerson.all

        encoded = PaginatedPerson.collection_coder.dump(collection)

        assert_equal collection.encode, encoded
        assert_equal @paginated_people.send("to_#{format}"), encoded
      end
    end
  end

  test "#dump encodes a Hash collection with a custom encoder" do
    [ :json, :xml ].each do |format|
      using_format Person, format do
        coder = ActiveResource::Coder.new(Person, :original_parsed, collection: true)
        collection = Person.all

        encoded = coder.dump(collection)

        assert_equal collection.original_parsed, encoded
      end
    end
  end

  test "#dump raises an ArgumentError is passed anything but an ActiveResource::Base" do
    assert_raises ArgumentError, match: "expected value to be ActiveResource::Collection, but was Integer" do
      Person.collection_coder.dump(1)
    end
    assert_raises ArgumentError, match: "expected value to be PaginatedCollection, but was Integer" do
      PaginatedPerson.collection_coder.dump(1)
    end
  end

  private
    def using_format(klass, mime_type_reference)
      previous_format = klass.format
      klass.format = mime_type_reference

      yield
    ensure
      klass.format = previous_format
    end
end
