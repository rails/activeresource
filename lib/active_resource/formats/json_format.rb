# frozen_string_literal: true

require "active_support/json"

module ActiveResource
  module Formats
    module JsonFormat
      extend self

      def extension
        "json"
      end

      def mime_type
        "application/json"
      end

      def encode(resource, options = nil)
        resource.to_json(options)
      end

      def decode(json)
        return nil if json.nil?
        Formats.remove_root(ActiveSupport::JSON.decode(json))
      end
    end
  end
end
