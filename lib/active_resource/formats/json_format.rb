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

      def decode(json, remove_root = true)
        return nil if json.nil?
        hash = ActiveSupport::JSON.decode(json)
        remove_root ? Formats.remove_root(hash) : hash
      end
    end
  end
end
