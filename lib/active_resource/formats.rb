# frozen_string_literal: true

module ActiveResource
  module Formats
    autoload :XmlFormat, "active_resource/formats/xml_format"
    autoload :JsonFormat, "active_resource/formats/json_format"

    BUILT_IN = HashWithIndifferentAccess.new(
      xml: ActiveResource::Formats::XmlFormat,
      json: ActiveResource::Formats::JsonFormat,
    ).freeze

    # Lookup the format class from a mime type reference symbol. Example:
    #
    #   ActiveResource::Formats[:xml]  # => ActiveResource::Formats::XmlFormat
    #   ActiveResource::Formats[:json] # => ActiveResource::Formats::JsonFormat
    def self.[](mime_type_reference)
      BUILT_IN.fetch(mime_type_reference) do
        ActiveResource::Formats.const_get(ActiveSupport::Inflector.camelize(mime_type_reference.to_s) + "Format")
      end
    end

    def self.remove_root(data)
      if data.is_a?(Hash) && data.keys.size == 1 && data.values.first.is_a?(Enumerable)
        data.values.first
      else
        data
      end
    end
  end
end
