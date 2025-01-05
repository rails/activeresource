# frozen_string_literal: true

require "active_support/core_ext/array/wrap"

module ActiveResource
  # = Active Resource \Callbacks
  #
  # \Callbacks are hooks into the life cycle of an Active Resource object that allow you to trigger logic
  # before or after a change in the object state. Active Resources instances trigger callbacks for the following methods:
  #
  # * <tt>save</tt> (<tt>around_save</tt>, <tt>before_save</tt>, <tt>after_save</tt>)
  # * <tt>create</tt> (<tt>around_create</tt>, <tt>before_create</tt>, <tt>after_create</tt>)
  # * <tt>update</tt> (<tt>around_update</tt>, <tt>before_update</tt>, <tt>after_update</tt>)
  # * <tt>destroy</tt> (<tt>around_destroy</tt>, <tt>before_destroy</tt>, <tt>after_destroy</tt>)
  # * <tt>reload</tt> (<tt>around_reload</tt>, <tt>before_reload</tt>, <tt>after_reload</tt>)
  #
  # As an example of the callbacks initiated, consider the {ActiveResource::Base#save}[rdoc-ref:Base#save] call for a new resource:
  #
  # * (-) <tt>save</tt>
  # * (-) <tt>valid?</tt>
  # * (1) <tt>before_validation</tt>
  # * (-) <tt>validate</tt>
  # * (2) <tt>after_validation</tt>
  # * (3) <tt>before_save</tt>
  # * (4) <tt>before_create</tt>
  # * (-) <tt>create</tt>
  # * (5) <tt>after_create</tt>
  # * (6) <tt>after_save</tt>
  #
  # == Canceling callbacks
  #
  # If a <tt>before_*</tt> callback throws +:abort+, all the later callbacks and
  # the associated action are cancelled.
  # \Callbacks are generally run in the order they are defined, with the exception of callbacks defined as
  # methods on the model, which are called last.
  #
  # == Debugging callbacks
  #
  # The callback chain is accessible via the <tt>_*_callbacks</tt> method on an object. Active Model \Callbacks support
  # <tt>:before</tt>, <tt>:after</tt> and <tt>:around</tt> as values for the <tt>kind</tt> property. The <tt>kind</tt> property
  # defines what part of the chain the callback runs in.
  #
  # To find all callbacks in the +before_save+ callback chain:
  #
  #   Topic._save_callbacks.select { |cb| cb.kind.eql?(:before) }
  #
  # Returns an array of callback objects that form the +before_save+ chain.
  #
  # To further check if the before_save chain contains a proc defined as <tt>rest_when_dead</tt> use the <tt>filter</tt> property of the callback object:
  #
  #   Topic._save_callbacks.select { |cb| cb.kind.eql?(:before) }.collect(&:filter).include?(:rest_when_dead)
  #
  # Returns true or false depending on whether the proc is contained in the +before_save+ callback chain on a Topic model.
  module Callbacks
    extend ActiveSupport::Concern

    CALLBACKS = [
      :before_validation, :after_validation, :before_save, :around_save, :after_save,
      :before_create, :around_create, :after_create, :before_update, :around_update,
      :after_update, :before_destroy, :around_destroy, :after_destroy,
      :before_reload, :around_reload, :after_reload
    ]

    included do
      extend ActiveModel::Callbacks
      include ActiveModel::Validations::Callbacks

      define_model_callbacks :save, :create, :update, :destroy, :reload
    end
  end
end
