# frozen_string_literal: true

require "active_support/core_ext/module/delegation"
require "active_support/inflector"

module ActiveResource # :nodoc:
  class Collection # :nodoc:
    include Enumerable
    delegate :to_yaml, *Array.public_instance_methods(false), to: :request_resources!

    attr_accessor :resource_class, :query_params, :path_params
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
      @requested = false
      # This can get called without a response, so parse only if response is present
      parse_response(@elements) if @elements.present?
    end

    # Processes and sets the collection elements. This method assigns the provided `elements`
    # (or an empty array if none provided) to the `@elements` instance variable.
    #
    # ==== Arguments
    #
    # +elements+ (Array<Object>) - An optional array of resources to be set as the collection elements.
    #                              Defaults to an empty array.
    #
    # This method is called after fetching the resource and can be overridden by subclasses to
    # handle any specific response format of the API.
    def parse_response(elements)
      @elements = elements || []
    end

    # Returns the prefix options for the collection, which are used for constructing the resource path.
    #
    # ==== Returns
    #
    # [Hash] The prefix options for the collection.
    def prefix_options
      @prefix_options || {}
    end

    # Refreshes the collection by re-fetching the resources from the API.
    #
    # ==== Returns
    #
    # [Array<Object>] The collection of resources retrieved from the API.
    def refresh
      @requested = false
      request_resources!
    end

    # Executes the request to fetch the collection of resources from the API and returns the collection.
    #
    # ==== Returns
    #
    # [ActiveResource::Collection] The collection of resources.
    def call
      request_resources!
      self
    end

    # Checks if the collection has been requested.
    #
    # ==== Returns
    #
    # [Boolean] true if the collection has been requested, false otherwise.
    def requested?
      @requested
    end

    # Returns the first resource in the collection, or creates a new resource using the provided
    # attributes if the collection is empty.
    #
    # ==== Arguments
    #
    # +attributes+ (Hash) - The attributes for creating the resource.
    #
    # ==== Returns
    #
    # [Object] The first resource, or a newly created resource if none exist.
    #
    # ==== Example
    #   post = PostCollection.where(title: "New Post").first_or_create
    #   # => Post instance with title "New Post"
    def first_or_create(attributes = {})
      first || resource_class.create(query_params.update(attributes))
    rescue NoMethodError
      raise "Cannot create resource from resource type: #{resource_class.inspect}"
    end

    # Returns the first resource in the collection, or initializes a new resource using the provided
    # attributes if the collection is empty.
    #
    # ==== Arguments
    #
    # +attributes+ (Hash) - The attributes for initializing the resource.
    #
    # ==== Returns
    #
    # [Object] The first resource, or a newly initialized resource if none exist.
    #
    # ==== Example
    #   post = PostCollection.where(title: "New Post").first_or_initialize
    #   # => Post instance with title "New Post"
    def first_or_initialize(attributes = {})
      first || resource_class.new(query_params.update(attributes))
    rescue NoMethodError
      raise "Cannot build resource from resource type: #{resource_class.inspect}"
    end

    # Filters the collection based on the provided clauses (query parameters).
    #
    # ==== Arguments
    #
    # +clauses+ (Hash) - A hash of query parameters used to filter the collection.
    #
    # ==== Returns
    #
    # [ActiveResource::Collection] A new collection filtered by the specified clauses.
    #
    # ==== Example
    #   filtered_posts = PostCollection.where(title: "Post 1")
    #   # => PostCollection:xxx (filtered collection)
    def where(clauses = {})
      raise ArgumentError, "expected a clauses Hash, got #{clauses.inspect}" unless clauses.is_a? Hash
      new_clauses = query_params.merge(clauses)
      resource_class.where(new_clauses)
    end

    private
      def query_string(options)
        "?#{options.to_query}" unless options.nil? || options.empty?
      end

      # Requests resources from the API and parses the response. The resources are then mapped to their respective
      # resource class instances.
      #
      # ==== Returns
      #
      # [Array<Object>] The collection of resources retrieved from the API.
      def request_resources!
        return @elements if requested?
        response =
          case from
          when Symbol
            resource_class.get(from, path_params)
          when String
            path = "#{from}#{query_string(query_params)}"
            resource_class.format.decode(resource_class.connection.get(path, resource_class.headers).body)
          else
            path = resource_class.collection_path(prefix_options, query_params)
            resource_class.format.decode(resource_class.connection.get(path, resource_class.headers).body)
          end

        # Update the elements
        parse_response(response)
        @elements.map! { |e| resource_class.instantiate_record(e, prefix_options) }
      rescue ActiveResource::ResourceNotFound
        # Swallowing ResourceNotFound exceptions and return nothing - as per ActiveRecord.
        # Needs to be empty array as Array methods are delegated
        []
      ensure
        @requested = true
      end
  end
end
