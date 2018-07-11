require 'active_support/json'

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

      def encode(hash, options = nil)
        ActiveSupport::JSON.encode(hash, options)
      end

      def decode(json, response_array_key = nil)
        return nil if json.nil?
        return Formats.remove_root(ActiveSupport::JSON.decode(json)) if response_array_key.nil?
        Formats.remove_root(ActiveSupport::JSON.decode(json)[response_array_key])
      end
    end
  end
end
