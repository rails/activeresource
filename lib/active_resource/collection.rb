# frozen_string_literal: true

require "active_support/core_ext/module/delegation"
require "active_support/inflector"

module ActiveResource # :nodoc:
  class Collection # :nodoc:
    SELF_DEFINE_METHODS = [:to_a, :all?]
    include Enumerable
    delegate :to_yaml, :all?, *(Array.instance_methods(false) - SELF_DEFINE_METHODS), to: :to_a

    # The array of actual elements returned by index actions
    attr_accessor :elements, :resource_class, :original_params, :path_params
    attr_writer :prefix_options
    attr_reader :from

    # ActiveResource::Collection is a wrapper to handle parsing index responses that
    # do not directly map to Rails conventions.
    #
    # You can define a custom class that inherits from ActiveResource::Collection
    # in order to to set the elements instance.
    #
    # GET /posts.json delivers following response body:
    #   {
    #     posts: [
    #       {
    #         title: "ActiveResource now has associations",
    #         body: "Lorem Ipsum"
    #       },
    #       {...}
    #     ],
    #     next_page: "/posts.json?page=2"
    #   }
    #
    # A Post class can be setup to handle it with:
    #
    #   class Post < ActiveResource::Base
    #     self.site = "http://example.com"
    #     self.collection_parser = PostCollection
    #   end
    #
    # And the collection parser:
    #
    #   class PostCollection < ActiveResource::Collection
    #     attr_accessor :next_page
    #     def parse_response(parsed = {})
    #       @elements = parsed['posts']
    #       @next_page = parsed['next_page']
    #     end
    #   end
    #
    # The result from a find method that returns multiple entries will now be a
    # PostParser instance.  ActiveResource::Collection includes Enumerable and
    # instances can be iterated over just like an array.
    #    @posts = Post.find(:all) # => PostCollection:xxx
    #    @posts.next_page         # => "/posts.json?page=2"
    #    @posts.map(&:id)         # =>[1, 3, 5 ...]
    #
    # The ActiveResource::Collection#parse_response method will receive the ActiveResource::Formats parsed result
    # and should set @elements.
    def initialize(elements = [], from = nil)
      @from = from
      @elements = elements
      # This can get called without a response, so parse only if response is present
      parse_response(@elements) if @elements.present?
    end

    def parse_response(elements)
      @elements = elements || []
    end

    def prefix_options
      @prefix_options || {}
    end

    # Makes network request to get the elements and returns self
    def call
      to_a
      self
    end

    def to_a
      response =
        case from
        when Symbol
          resource_class.get(from, path_params)
        when String
          path = "#{from}#{query_string(original_params)}"
          resource_class.format.decode(resource_class.connection.get(path, resource_class.headers).body)
        else
          path = resource_class.collection_path(prefix_options, original_params)
          resource_class.format.decode(resource_class.connection.get(path, resource_class.headers).body)
        end

      # Update the elements
      parse_response(response)
      @elements = @elements.map do |element|
        resource_class.instantiate_record(element, prefix_options)
      end
    rescue ActiveResource::ResourceNotFound
      # Swallowing ResourceNotFound exceptions and return nothing - as per ActiveRecord.
      # Needs to be empty array as Array methods are delegated
      []
    end

    def first_or_create(attributes = {})
      first || resource_class.create(original_params.update(attributes))
    rescue NoMethodError
      raise "Cannot create resource from resource type: #{resource_class.inspect}"
    end

    def first_or_initialize(attributes = {})
      first || resource_class.new(original_params.update(attributes))
    rescue NoMethodError
      raise "Cannot build resource from resource type: #{resource_class.inspect}"
    end

    def where(clauses = {})
      raise ArgumentError, "expected a clauses Hash, got #{clauses.inspect}" unless clauses.is_a? Hash
      new_clauses = original_params.merge(clauses)
      resource_class.where(new_clauses)
    end

    private
      def query_string(options)
        "?#{options.to_query}" unless options.nil? || options.empty?
      end
  end
end
