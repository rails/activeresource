# frozen_string_literal: true

module ActiveResource
  module Associations
    module ActiveRecord
      def belongs_to_resource(name, class_name: nil)
        klass = class_name&.constantize || name.to_s.classify.constantize
        define_method(name) { klass.find(send("#{name}_id")) }
      end
    end
  end
end
