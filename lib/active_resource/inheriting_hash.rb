# frozen_string_literal: true

module ActiveResource
  class InheritingHash < Hash
    def initialize(parent_hash = {})
      # Default hash value must be nil, which allows fallback lookup on parent hash
      super(nil)
      @parent_hash = parent_hash
    end

    def [](key)
      super || @parent_hash[key]
    end
  end
end
