# frozen_string_literal: true

require "active_support/core_ext/array/wrap"
require "active_support/core_ext/object/blank"

module ActiveResource
  class ResourceInvalid < ClientError  # :nodoc:
  end

  # Active Resource validation is reported to and from this object, which is used by Base#save
  # to determine whether the object in a valid state to be saved. See usage example in Validations.
  class Errors < ActiveModel::Errors
    # Grabs errors from an array of messages (like ActiveRecord::Validations).
    # The second parameter directs the errors cache to be cleared (default)
    # or not (by passing true).
    def from_array(messages, save_cache = false)
      errors = Hash.new { |hash, attr_name| hash[attr_name] = [] }
      humanized_attributes = Hash[@base.known_attributes.map { |attr_name| [ attr_name.humanize, attr_name ] }]
      messages.each_with_object(errors) do |message, hash|
        attr_message = humanized_attributes.keys.sort_by { |a| -a.length }.detect do |attr_name|
          if message[0, attr_name.size + 1] == "#{attr_name} "
            hash[humanized_attributes[attr_name]] << message[(attr_name.size + 1)..-1]
          end
        end
        hash["base"] << message if attr_message.nil?
      end

      from_hash errors, save_cache
    end

    # Grabs errors from a hash of attribute => array of errors elements
    # The second parameter directs the errors cache to be cleared (default)
    # or not (by passing true)
    #
    # Unrecognized attribute names will be humanized and added to the record's
    # base errors.
    def from_hash(messages, save_cache = false)
      clear unless save_cache

      messages.each do |(key, errors)|
        errors.each do |error|
          if @base.known_attributes.include?(key)
            add key, error
          elsif key == "base"
            add(:base, error)
          else
            # reporting an error on an attribute not in attributes
            # format and add them to base
            add(:base, "#{key.humanize} #{error}")
          end
        end
      end
    end

    # Grabs errors from a json response.
    def from_json(json, save_cache = false)
      from_body json, save_cache, format: Formats[:json]
    end

    # Grabs errors from an XML response.
    def from_xml(xml, save_cache = false)
      from_body xml, save_cache, format: Formats[:xml]
    end

    ##
    # :method: from_body
    #
    # :call-seq:
    #     from_body(body, save_cache = false)
    #
    # Grabs errors from a response body.
    def from_body(body, save_cache = false, format: @base.class.format)
      decoded = format.decode(body, false) || {} rescue {}
      errors = @base.class.errors_parser.new(decoded).tap do |parser|
        parser.format = format
      end.messages

      if errors.is_a?(Array)
        from_array errors, save_cache
      else
        from_hash errors, save_cache
      end
    end
  end

  # ActiveResource::ErrorsParser is a wrapper to handle parsing responses in
  # response to invalid requests that do not directly map to Active Model error
  # conventions.
  #
  # You can define a custom class that inherits from ActiveResource::ErrorsParser
  # in order to to set the elements instance.
  #
  # The initialize method will receive the ActiveResource::Formats parsed result
  # and should set @messages.
  #
  # ==== Example
  #
  # Consider a POST /posts.json request that results in a 422 Unprocessable
  # Content response with the following +application/json+ body:
  #
  #   {
  #     "error": true,
  #     "messages": ["Something went wrong", "Title can't be blank"]
  #   }
  #
  # A Post class can be setup to handle it with:
  #
  #   class Post < ActiveResource::Base
  #     self.errors_parser = PostErrorsParser
  #   end
  #
  # A custom ActiveResource::ErrorsParser instance's +messages+ method should
  # return a mapping of attribute names (or +"base"+) to arrays of error message
  # strings:
  #
  #   class PostErrorsParser < ActiveResource::ErrorsParser
  #     def initialize(parsed)
  #       @messages = Hash.new { |hash, attr_name| hash[attr_name] = [] }
  #
  #       parsed["messages"].each do |message|
  #         if message.starts_with?("Title")
  #           @messages["title"] << message
  #         else
  #           @messages["base"] << message
  #         end
  #       end
  #     end
  #   end
  #
  # When the POST /posts.json request is submitted by calling +save+, the errors
  # are parsed from the body and assigned to the Post instance's +errors+
  # object:
  #
  #   post = Post.new(title: "")
  #   post.save                         # => false
  #   post.valid?                       # => false
  #   post.errors.messages_for(:base)   # => ["Something went wrong"]
  #   post.errors.messages_for(:title)  # => ["Title can't be blank"]
  #
  # If the custom ActiveResource::ErrorsParser instance's +messages+ method
  # returns an array of error message strings, Active Resource will try to infer
  # the attribute name based on the contents of the error message string. If an
  # error starts with a known attribute name, Active Resource will add the
  # message to that attribute's error messages. If a known attribute name cannot
  # be inferred, the error messages will be added to the +:base+ errors:
  #
  #   class PostErrorsParser < ActiveResource::ErrorsParser
  #     def initialize(parsed)
  #       @messages = parsed["messages"]
  #     end
  #   end
  #
  #   post = Post.new(title: "")
  #   post.save                         # => false
  #   post.valid?                       # => false
  #   post.errors.messages_for(:base)   # => ["Something went wrong"]
  #   post.errors.messages_for(:title)  # => ["Title can't be blank"]
  class ErrorsParser
    attr_accessor :messages
    attr_accessor :format

    def initialize(parsed)
      @messages = parsed
    end
  end

  class ActiveModelErrorsParser < ErrorsParser # :nodoc:
    def messages
      if format.is_a?(Formats[:xml])
        Array.wrap(super["errors"]["error"]) rescue []
      else
        super["errors"] || {} rescue {}
      end
    end
  end

  # Module to support validation and errors with Active Resource objects. The module overrides
  # Base#save to rescue exceptions and parse the errors returned
  # in the web service response. The module also adds an +errors+ collection that mimics the interface
  # of the errors provided by ActiveModel::Errors.
  #
  # By default, Active Resource will raise, then rescue from ActiveResource::ResourceInvalid
  # exceptions for a response with a +422+ status code. Set the +remote_errors+
  # class attribute to rescue from other exceptions.
  #
  # ==== Example
  #
  # Consider a Person resource on the server requiring both a +first_name+ and a +last_name+ with a
  # <tt>validates_presence_of :first_name, :last_name</tt> declaration in the model:
  #
  #   person = Person.new(first_name: "Jim", last_name: "")
  #   person.save                   # => false (server returns an HTTP 422 status code and errors)
  #   person.valid?                 # => false
  #   person.errors.empty?          # => false
  #   person.errors.count           # => 1
  #   person.errors.full_messages   # => ["Last name can't be empty"]
  #   person.errors[:last_name]     # => ["can't be empty"]
  #   person.last_name = "Halpert"
  #   person.save                   # => true (and person is now saved to the remote service)
  #
  # Consider a POST /people.json request that results in a 422 Unprocessable
  # Content response with the following +application/json+ body:
  #
  #   {
  #     "errors": {
  #       "base": ["Something went wrong"],
  #       "address": ["is invalid"]
  #     }
  #   }
  #
  # By default, Active Resource will automatically load errors from JSON response
  # objects that have a top-level +"errors"+ key that maps attribute names to arrays of
  # error message strings:
  #
  #   person = Person.new(first_name: "Jim", last_name: "Halpert", address: "123 Fake Street")
  #   person.save                   # => false (server returns an HTTP 422 status code and errors)
  #   person.valid?                 # => false
  #   person.errors[:base]          # => ["Something went wrong"]
  #   person.errors[:address]       # => ["is invalid"]
  #
  # Consider a POST /people.xml request that results in a 422 Unprocessable
  # Content response with the following +application/xml+ body:
  #
  #   <errors>
  #     <error>Something went wrong</error>
  #     <error>Address is invalid</error>
  #   </errors>
  #
  # By default, Active Resource will automatically load errors from XML response
  # documents that have a top-level +<errors>+ element that contains +<error>+
  # children that have error message content. When an error message starts with
  # an attribute name, Active Resource will automatically infer that attribute
  # name and add the message to the attribute's errors. When an attribute name
  # cannot be inferred, the error message will be added to the +:base+ errors:
  #
  #   person = Person.new(first_name: "Jim", last_name: "Halpert", address: "123 Fake Street")
  #   person.save                   # => false (server returns an HTTP 422 status code and errors)
  #   person.valid?                 # => false
  #   person.errors[:base]          # => ["Something went wrong"]
  #   person.errors[:address]       # => ["Address is invalid"]
  module Validations
    extend  ActiveSupport::Concern
    include ActiveModel::Validations

    included do
      alias_method :save_without_validation, :save
      alias_method :save, :save_with_validation
      class_attribute :_remote_errors, instance_accessor: false
      class_attribute :_errors_parser, instance_accessor: false
    end

    class_methods do
      # Sets the exception classes to rescue from during Base#save.
      def remote_errors=(errors)
        errors = Array.wrap(errors)
        errors.map! { |error| error.is_a?(String) ? error.constantize : error }
        self._remote_errors = errors
      end

      # Returns the exception classes rescued from during Base#save. Defaults to
      # ActiveResource::ResourceInvalid.
      def remote_errors
        _remote_errors.presence || ResourceInvalid
      end

      # Sets the parser to use when a response with errors is returned.
      def errors_parser=(parser_class)
        parser_class = parser_class.constantize if parser_class.is_a?(String)
        self._errors_parser = parser_class
      end

      def errors_parser
        _errors_parser || ActiveResource::ActiveModelErrorsParser
      end
    end

    # Validate a resource and save (POST) it to the remote web service.
    # If any local validations fail - the save (POST) will not be attempted.
    def save_with_validation(options = {})
      perform_validation = options[:validate] != false

      # clear the remote validations so they don't interfere with the local
      # ones. Otherwise we get an endless loop and can never change the
      # fields so as to make the resource valid.
      @remote_errors = nil
      if perform_validation && valid?(options[:context]) || !perform_validation
        save_without_validation
        true
      else
        false
      end
    rescue *self.class.remote_errors => error
      # cache the remote errors because every call to <tt>valid?</tt> clears
      # all errors. We must keep a copy to add these back after local
      # validations.
      @remote_errors = error
      load_remote_errors(@remote_errors, true)
      false
    end


    # Loads the set of remote errors into the object's Errors based on the
    # content-type of the error-block received.
    def load_remote_errors(remote_errors, save_cache = false) # :nodoc:
      errors.from_body(remote_errors.response.body, save_cache)
    end

    # Checks for errors on an object (i.e., is resource.errors empty?).
    #
    # Runs all the specified local validations and returns true if no errors
    # were added, otherwise false.
    # Runs local validations (eg those on your Active Resource model), and
    # also any errors returned from the remote system the last time we
    # saved.
    # Remote errors can only be cleared by trying to re-save the resource.
    #
    # If the argument is +false+ (default is +nil+), the context is set to <tt>:create</tt> if
    # {new_record?}[rdoc-ref:Base#new_record?] is +true+, and to <tt>:update</tt> if it is not.
    # If the argument is an array of contexts, <tt>post.valid?([:create, :update])</tt>, the validations are
    # run within multiple contexts.
    #
    # \Validations with no <tt>:on</tt> option will run no matter the context. \Validations with
    # some <tt>:on</tt> option will only run in the specified context.
    #
    # ==== Examples
    #   my_person = Person.create(params[:person])
    #   my_person.valid?
    #   # => true
    #
    #   my_person.errors.add('login', 'can not be empty') if my_person.login == ''
    #   my_person.valid?
    #   # => false
    #
    def valid?(context = nil)
      context ||= new_record? ? :create : :update

      run_callbacks :validate do
        super
        load_remote_errors(@remote_errors, true) if defined?(@remote_errors) && @remote_errors.present?
        errors.empty?
      end
    end

    # Returns the Errors object that holds all information about attribute error messages.
    def errors
      @errors ||= Errors.new(self)
    end
  end
end
