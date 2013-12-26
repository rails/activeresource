require 'active_support/core_ext/module/attribute_accessors'

module ActiveResource
    module Dirty # :nodoc:
      extend ActiveSupport::Concern
      include ActiveModel::Dirty

      included do
        class_attribute :partial_writes, instance_writer: false
        self.partial_writes = false
      end

      # Attempts to +save+ the record and clears changed attributes if successful.
      def save(*)
        if status = super
          @previously_changed = changes
          changed_attributes.clear
        end
        status
      end

      # <tt>reload</tt> the record and clears changed attributes.
      def reload(*)
        super.tap do
          previously_changed.clear
          changed_attributes.clear
        end
      end

      def previously_changed
        @previously_changed ||= {}.with_indifferent_access
      end

      def changed_attributes
        @changed_attributes ||= {}.with_indifferent_access
      end

      def method_missing(method_symbol, *arguments) #:nodoc:
        method_name = method_symbol.to_s
        if method_name =~ /(=)$/
          new_value = arguments.first
          if attribute_changed?($`) && changed_attributes[$`] == new_value
            # Reset status if already changed and we are returning to the original value
            changed_attributes.delete($`)
          elsif attributes[$`] != new_value
            # yield change if value changed otherwise
            attribute_will_change!($`)
          end
        end
        super
      end

      def encode(options={})
        if persisted? && self.partial_writes
          encode_changed_attributes(options)
        else
          super
        end
      end

      def encode_changed_attributes(options={})
        send("to_#{self.class.format.extension}", options.merge({:only => keys_for_partial_write}))
      end

      def keys_for_partial_write
        changed_attributes.keys
      end

      def non_zero?(value)
        value !~ /\A0+(\.0+)?\z/
      end
    end
end