# frozen_string_literal: true

module ActiveResource
  class ActiveJobSerializer < ActiveJob::Serializers::ObjectSerializer
    def serialize(resource)
      super(
        "class" => resource.class.name,
        "persisted" => resource.persisted?,
        "prefix_options" => resource.prefix_options.as_json,
        "attributes" => resource.attributes.as_json
      )
    end

    def deserialize(hash)
      hash["class"].constantize.new(hash["attributes"]).tap do |resource|
        resource.persisted      = hash["persisted"]
        resource.prefix_options = hash["prefix_options"]
      end
    end

    private
      def klass
        ActiveResource::Base
      end
  end
end
