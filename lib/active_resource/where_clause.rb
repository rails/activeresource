# frozen_string_literal: true

module ActiveResource
  class WhereClause < BasicObject # :nodoc:
    delegate :==, to: :collection
    delegate_missing_to :collection

    def initialize(resource_class, options = {})
      @resource_class = resource_class
      @options = options
      @collection = nil
      @loaded = false
    end

    def where(clauses = {})
      all(params: clauses)
    end

    def all(options = {})
      WhereClause.new(@resource_class, @options.deep_merge(options))
    end

    def load
      unless @loaded
        @collection = @resource_class.find(:all, @options)
        @loaded = true
      end

      self
    end

    def reload
      reset
      load
    end

    def collection
      load
      @collection
    end

    private

      def reset
        @collection = nil
        @loaded = false
      end
  end
end
