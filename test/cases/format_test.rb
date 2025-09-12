# frozen_string_literal: true

require "abstract_unit"
require "fixtures/person"
require "fixtures/street_address"

class FormatTest < ActiveSupport::TestCase
  def setup
    @matz  = { id: 1, name: "Matz" }
    @david = { id: 2, name: "David" }

    @programmers = [ @matz, @david ]
  end

  def test_http_format_header_name
    [ :get, :head ].each do |verb|
      header_name = ActiveResource::Connection::HTTP_FORMAT_HEADER_NAMES[verb]
      assert_equal "Accept", header_name
    end

    [ :patch, :put, :post ].each do |verb|
      header_name = ActiveResource::Connection::HTTP_FORMAT_HEADER_NAMES[verb]
      assert_equal "Content-Type", header_name
    end
  end

  def test_formats_on_single_element
    [ :json, :xml ].each do |format|
      using_format(Person, format) do
        ActiveResource::HttpMock.respond_to.get "/people/1.#{format}", { "Accept" => ActiveResource::Formats[format].mime_type }, ActiveResource::Formats[format].encode(@david)
        assert_equal @david[:name], Person.find(1).name
      end
    end
  end

  def test_formats_on_collection
    [ :json, :xml ].each do |format|
      using_format(Person, format) do
        ActiveResource::HttpMock.respond_to.get "/people.#{format}", { "Accept" => ActiveResource::Formats[format].mime_type }, ActiveResource::Formats[format].encode(@programmers)
        remote_programmers = Person.find(:all)
        assert_equal 2, remote_programmers.size
        assert remote_programmers.find { |p| p.name == "David" }
      end
    end
  end

  def test_formats_on_custom_collection_method
    [ :json, :xml ].each do |format|
      using_format(Person, format) do
        ActiveResource::HttpMock.respond_to.get "/people/retrieve.#{format}?name=David", { "Accept" => ActiveResource::Formats[format].mime_type }, ActiveResource::Formats[format].encode([ @david ])
        remote_programmers = Person.get(:retrieve, name: "David")
        assert_equal 1, remote_programmers.size
        assert_equal @david[:id], remote_programmers[0]["id"]
        assert_equal @david[:name], remote_programmers[0]["name"]
      end
    end
  end

  def test_formats_on_custom_element_method
    [ :json, :xml ].each do |format|
      using_format(Person, format) do
        david = (format == :json ? { person: @david } : @david)
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/people/2.#{format}", { "Accept" => ActiveResource::Formats[format].mime_type }, ActiveResource::Formats[format].encode(david)
          mock.get "/people/2/shallow.#{format}", { "Accept" => ActiveResource::Formats[format].mime_type }, ActiveResource::Formats[format].encode(david)
        end

        remote_programmer = Person.find(2).get(:shallow)
        assert_equal @david[:id], remote_programmer["id"]
        assert_equal @david[:name], remote_programmer["name"]
      end

      ryan_hash = { name: "Ryan" }
      ryan_hash = (format == :json ? { person: ryan_hash } : ryan_hash)
      ryan = ActiveResource::Formats[format].encode(ryan_hash)
      using_format(Person, format) do
        remote_ryan = Person.new(name: "Ryan")
        ActiveResource::HttpMock.respond_to.post "/people.#{format}", { "Content-Type" => ActiveResource::Formats[format].mime_type }, ryan, 201, "Location" => "/people/5.#{format}"
        remote_ryan.save

        remote_ryan = Person.new(name: "Ryan")
        ActiveResource::HttpMock.respond_to.post "/people/new/register.#{format}", { "Content-Type" => ActiveResource::Formats[format].mime_type }, ryan, 201, "Location" => "/people/5.#{format}"
        assert_equal ActiveResource::Response.new(ryan, 201, "Location" => "/people/5.#{format}"), remote_ryan.post(:register)
      end
    end
  end

  def test_setting_format_before_site
    resource = Class.new(ActiveResource::Base)
    resource.format = :json
    resource.site   = "http://37s.sunrise.i:3000"
    assert_equal ActiveResource::Formats[:json], resource.connection.format
  end

  def test_serialization_of_nested_resource
    address = { street: "12345 Street" }
    person = { name: "Rus", address: address }

    [ :json, :xml ].each do |format|
      encoded_person = ActiveResource::Formats[format].encode(person)
      assert_match(/12345 Street/, encoded_person)
      remote_person = Person.new(person.update(address: StreetAddress.new(address)))
      assert_kind_of StreetAddress, remote_person.address
      using_format(Person, format) do
        ActiveResource::HttpMock.respond_to.post "/people.#{format}", { "Content-Type" => ActiveResource::Formats[format].mime_type }, encoded_person, 201, "Location" => "/people/5.#{format}"
        remote_person.save
      end
    end
  end

  def test_custom_json_format
    format_class = Class.new do
      include ActiveResource::Formats[:json]

      def initialize(encoder:, decoder:)
        @encoder, @decoder = encoder, decoder
      end

      def encode(resource, options = nil)
        hash = resource.as_json(options)
        hash = hash.deep_transform_keys!(&@encoder)
        super(hash)
      end

      def decode(json)
        super.deep_transform_keys!(&@decoder)
      end
    end

    format = format_class.new(encoder: ->(key) { key.camelcase(:lower) }, decoder: :underscore)

    using_format(Person, format) do
      person = Person.new(name: "Joe", likes_hats: true)
      json = { person: { name: "Joe", likesHats: true } }.to_json

      assert_equal person, Person.new(format.decode(json))
      assert_equal person.encode, json
    end
  end

  def test_custom_xml_format
    format = Module.new do
      extend self, ActiveResource::Formats[:xml]

      def encode(value, options = {})
        xml = value.serializable_hash(options)
        xml.deep_transform_keys!(&:camelcase)
        super(xml, root: value.class.element_name)
      end

      def decode(value)
        super.deep_transform_keys!(&:underscore)
      end
    end

    using_format(Person, format) do
      person = Person.new(name: "Joe", likes_hats: true)
      xml = { Name: "Joe", "LikesHats": true }.to_xml(root: "person")

      assert_equal person, Person.new(format.decode(xml))
      assert_equal person.encode, xml
    end
  end

  def test_removing_root
    matz = { name: "Matz" }
    matz_with_root = { person: matz }

    # On Array
    people = [ matz ]
    assert_equal ActiveResource::Formats.remove_root(people), [ matz ]

    # On Hash with no root
    person = matz
    assert_equal ActiveResource::Formats.remove_root(person), matz

    # On Hash with root
    person = matz_with_root
    assert_equal ActiveResource::Formats.remove_root(person), matz
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
