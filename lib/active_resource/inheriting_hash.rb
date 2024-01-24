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

    # Merges the flattened parent hash (if it's an InheritingHash)
    # with ourself
    def to_hash
      @parent_hash.to_hash.merge(self)
    end

    # So we can see the merged object in IRB or the Rails console
    def pretty_print(pp)
      pp.pp_hash to_hash
    end

    def inspect
      to_hash.inspect
    end

    def to_s
      inspect
    end
  end
end
