# frozen_string_literal: true

module ActiveResource
  class AttributeSet < DelegateClass(Hash) # :nodoc:
    MESSAGE = "Writing to the attributes hash is deprecated. Set attributes directly on the instance instead."

    def []=(key, value)
      ActiveResource.deprecator.warn(MESSAGE)
      super
    end
    alias_method :store, :[]=

    def update(*other_hashes)
      ActiveResource.deprecator.warn(MESSAGE)
      super
    end
    alias_method :merge!, :update

    def is_a?(other)
      __getobj__.is_a?(other)
    end
  end
end
