# frozen_string_literal: true

require "abstract_unit"

class FormatsTest < ActiveSupport::TestCase
  def test_resolving_json_and_xml_formats_when_defined_as_acronyms
    ActiveSupport::Inflector.inflections do |inflect|
      inflect.acronym "JSON"
      inflect.acronym "XML"
    end

    assert_equal ActiveResource::Formats::JsonFormat, ActiveResource::Formats[:json]
    assert_equal ActiveResource::Formats::XmlFormat, ActiveResource::Formats[:xml]
  ensure
    ActiveSupport::Inflector.inflections do |inflect|
      # N.B. It's not yet possible to use the public ActiveSupport::Inflector::Inflections#clear
      # API because it doesn't reset @acronyms to be a Hash (the default value),
      # instead it sets an empty array.
      inflect.instance_variable_set(:@acronyms, {})
    end
  end

  def test_resolving_custom_formats_uses_const_get
    klass = Class.new
    ActiveResource::Formats.const_set(:MsgpackFormat, klass)

    assert_equal klass, ActiveResource::Formats[:msgpack]
  ensure
    ActiveResource::Formats.send(:remove_const, :MsgpackFormat)
  end
end
