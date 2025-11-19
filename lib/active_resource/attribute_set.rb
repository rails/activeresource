# frozen_string_literal: true

module ActiveResource
  class AttributeSet < DelegateClass(Hash) # :nodoc:
    MESSAGE = "Writing to the attributes hash is deprecated. Set attributes directly on the instance instead."

    deprecate(**[ :[]=, :store, :update, :merge! ].index_with(MESSAGE),
      deprecator: ActiveResource.deprecator)

    delegate :is_a?, to: :__getobj__
  end
end
