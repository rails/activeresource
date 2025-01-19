# frozen_string_literal: true

require "active_model/forbidden_attributes_protection"

module ActiveResource
  class ForbiddenAttributesError < ActiveModel::ForbiddenAttributesError
  end

  module ForbiddenAttributesProtection
    include ActiveModel::ForbiddenAttributesProtection

    private
      def sanitize_for_mass_assignment(attributes)
        super
      rescue ActiveModel::ForbiddenAttributesError
        raise ForbiddenAttributesError
      end
  end
end
