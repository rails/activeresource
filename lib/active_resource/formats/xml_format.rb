# frozen_string_literal: true

require "active_support/core_ext/hash/conversions"

module ActiveResource
  module Formats
    module XmlFormat
      extend self

      def extension
        "xml"
      end

      def mime_type
        "application/xml"
      end

      def encode(resource, options = {})
        resource.to_xml(options)
      end

      def decode(xml, remove_root = true)
        hash = Hash.from_xml(xml)
        remove_root ? Formats.remove_root(hash) : hash
      end
    end
  end
end
