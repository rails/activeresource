# frozen_string_literal: true

module ActiveResource
  module Casings
    class NoneCasing
      def encode(key)
        transform_key(key, &method(:encode_key))
      end

      def decode(key)
        transform_key(key, &method(:decode_key))
      end

      private
        def encode_key(key)
          key
        end

        def decode_key(key)
          key
        end

        def transform_key(key)
          transformed_key = yield key.to_s

          key.is_a?(Symbol) ? transformed_key.to_sym : transformed_key
        end
    end
  end
end
