# frozen_string_literal: true

module ActiveResource
  module Formats
    module UrlEncodedFormat
      extend self

      attr_accessor :query_parser # :nodoc:

      # URL encode the parameters Hash
      def encode(params, options = nil)
        params.to_query
      end

      # URL decode the query string
      def decode(query, remove_root = true)
        query = query.delete_prefix("?")

        if query_parser == :rack
          Rack::Utils.parse_nested_query(query)
        else
          URI.decode_www_form(query).to_h
        end
      end
    end
  end
end
