# frozen_string_literal: true

module ActiveResource
  module Dirty # :nodoc:
    extend ActiveSupport::Concern

    included do
      include ActiveModel::Dirty

      after_save :changes_applied
      after_reload :clear_changes_information

      private

      def mutations_from_database
        @mutations_from_database ||= ActiveModel::ForcedMutationTracker.new(self)
      end

      def forget_attribute_assignments
        # no-op
      end
    end
  end
end
