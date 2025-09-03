# frozen_string_literal: true

module ActiveResource
  class WhereClause < BasicObject # :nodoc:
    delegate_missing_to :resources

    def initialize(resource_class, options = {})
      @resource_class = resource_class
      @options = options
      @resources = nil
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
        @resources = @resource_class.find(:all, @options)
        @loaded = true
      end

      self
    end

    def reload
      reset
      load
    end

    private
      def resources
        load
        @resources
      end

      def reset
        @resources = nil
        @loaded = false
      end
  end
end
