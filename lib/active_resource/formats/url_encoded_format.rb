# frozen_string_literal: true

require "active_support/core_ext/array/wrap"

module ActiveResource
  module Formats
    module UrlEncodedFormat
      extend self

      # URL encode the parameters Hash
      def encode(params, options = nil)
        params.to_query
      end
    end
  end
end
