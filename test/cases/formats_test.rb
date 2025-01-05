# frozen_string_literal: true

require "abstract_unit"

class FormatsTest < ActiveSupport::TestCase
  def test_json_format_uses_camelcase
    assert_equal ActiveResource::Formats::JsonFormat, ActiveResource::Formats[:json]
  end

  def test_xml_format_uses_camelcase
    assert_equal ActiveResource::Formats::XmlFormat, ActiveResource::Formats[:xml]
  end

  def test_custom_format_uses_camelcase
    klass = Class.new
    ActiveResource::Formats.const_set(:MsgpackFormat, klass)

    assert_equal klass, ActiveResource::Formats[:msgpack]
  ensure
    ActiveResource::Formats.send(:remove_const, :MsgpackFormat)
  end

  def test_unknown_format_raises_not_found_error
    assert_raises NameError, match: "uninitialized constant ActiveResource::Formats::MsgpackFormat" do
      ActiveResource::Formats[:msgpack]
    end
  end

  def test_json_format_uses_acronym_inflections
    ActiveSupport::Inflector.inflections { |inflect| inflect.acronym "JSON" }

    assert_equal ActiveResource::Formats::JsonFormat, ActiveResource::Formats[:json]
  ensure
    ActiveSupport::Inflector.inflections.clear :acronyms
  end

  def test_xml_format_uses_acronym_inflections
    ActiveSupport::Inflector.inflections { |inflect| inflect.acronym "XML" }

    assert_equal ActiveResource::Formats::XmlFormat, ActiveResource::Formats[:xml]
  ensure
    ActiveSupport::Inflector.inflections.clear :acronyms
  end
end
