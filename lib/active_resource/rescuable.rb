# frozen_string_literal: true

module ActiveResource
  # = Active Resource \Rescuable
  #
  # Provides
  # {rescue_from}[rdoc-ref:ActiveSupport::Rescuable::ClassMethods#rescue_from]
  # for resources. Wraps calls over the network to handle configured errors.
  module Rescuable
    extend ActiveSupport::Concern

    included do
      include ActiveSupport::Rescuable

      around_save :handle_exceptions
      around_destroy :handle_exceptions
      around_reload :handle_exceptions
    end

    private
      def handle_exceptions
        yield
      rescue => exception
        rescue_with_handler(exception) || raise
      end
  end
end
