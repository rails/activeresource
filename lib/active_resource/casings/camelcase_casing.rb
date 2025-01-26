# frozen_string_literal: true

module ActiveResource
  module Casings
    class CamelcaseCasing < UnderscoreCasing
      def initialize(first_letter = :lower)
        super()
        @first_letter = first_letter
      end

      private
        def encode_key(key)
          key.camelcase(@first_letter)
        end
    end
  end
end
