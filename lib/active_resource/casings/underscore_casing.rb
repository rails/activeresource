# frozen_string_literal: true

module ActiveResource
  module Casings
    class UnderscoreCasing < NoneCasing
      private
        def encode_key(key)
          key.underscore
        end

        def decode_key(key)
          key.underscore
        end
    end
  end
end
