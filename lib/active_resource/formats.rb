module ActiveResource
  module Formats
    autoload :XmlFormat, 'active_resource/formats/xml_format'
    autoload :JsonFormat, 'active_resource/formats/json_format'

    # Lookup the format class from a mime type reference symbol. Example:
    #
    #   ActiveResource::Formats[:xml]  # => ActiveResource::Formats::XmlFormat
    #   ActiveResource::Formats[:json] # => ActiveResource::Formats::JsonFormat
    def self.[](mime_type_reference)
      ActiveResource::Formats.const_get(ActiveSupport::Inflector.camelize(mime_type_reference.to_s) + "Format")
    end

    def self.remove_root(data, klass=nil)
      if data.is_a?(Hash)
        if data.keys.size == 1
          data.values.first
        elsif klass && klass.remove_root
          data[klass.element_name.to_sym]
        else
          data
        end
      else
        data
      end
    end
  end
end
