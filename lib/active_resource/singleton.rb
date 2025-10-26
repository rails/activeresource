# frozen_string_literal: true

module ActiveResource
  # === Custom REST methods
  #
  # Since simple CRUD/life cycle methods can't accomplish every task, Singleton Resources can also support
  # defining custom REST methods. To invoke them, Active Resource provides the <tt>get</tt>,
  # <tt>post</tt>, <tt>put</tt> and <tt>delete</tt> methods where you can specify a custom REST method
  # name to invoke.
  #
  # Singleton resources use their <tt>singleton_name</tt> value as their default
  # <tt>collection_name</tt> value when constructing the request's path.
  #
  #   # GET to report on the Inventory, i.e. GET /products/1/inventory/report.json.
  #   Inventory.get(:report, product_id: 1)
  #   # => [{:count => 'Manager'}, {:name => 'Clerk'}]
  #
  #   # DELETE to 'reset' an inventory, i.e. DELETE /products/1/inventory/reset.json.
  #   Inventory.find(params: { product_id: 1 }).delete(:reset)
  #
  # For more information on using custom REST methods, see the
  # ActiveResource::CustomMethods documentation.
  module Singleton
    extend ActiveSupport::Concern

    module CustomMethods
      extend ActiveSupport::Concern

      module ClassMethods
        def collection_name
          @collection_name || singleton_name
        end
      end

      def custom_method_element_url(method_name, options = {})
        "#{self.class.prefix(prefix_options)}#{self.class.collection_name}/#{method_name}#{self.class.format_extension}#{self.class.__send__(:query_string, options)}"
      end
    end

    module ClassMethods
      attr_writer :singleton_name

      def singleton_name
        @singleton_name ||= model_name.element
      end

      # Gets the singleton path for the object.  If the +query_options+ parameter is omitted, Rails
      # will split from the \prefix options.
      #
      # ==== Options
      # * +prefix_options+ - A \hash to add a \prefix to the request for nested URLs (e.g., <tt>:account_id => 19</tt>
      # would yield a URL like <tt>/accounts/19/purchases.json</tt>).
      #
      # * +query_options+ - A \hash to add items to the query string for the request.
      #
      # ==== Examples
      #   Weather.singleton_path
      #   # => /weather.json
      #
      #   class Inventory < ActiveResource::Base
      #     self.site =   "https://37s.sunrise.com"
      #     self.prefix = "/products/:product_id/"
      #   end
      #
      #   Inventory.singleton_path(:product_id => 5)
      #   # => /products/5/inventory.json
      #
      #   Inventory.singleton_path({:product_id => 5}, {:sold => true})
      #   # => /products/5/inventory.json?sold=true
      #
      def singleton_path(prefix_options = {}, query_options = nil)
        check_prefix_options(prefix_options)

        prefix_options, query_options = split_options(prefix_options) if query_options.nil?
        "#{prefix(prefix_options)}#{singleton_name}#{format_extension}#{query_string(query_options)}"
      end

      # Core method for finding singleton resources.
      #
      # ==== Arguments
      # Takes a single argument of options
      #
      # ==== Options
      # * <tt>:params</tt> - Sets the query and \prefix (nested URL) parameters.
      #
      # ==== Examples
      #   Weather.find
      #   # => GET /weather.json
      #
      #   Weather.find(:params => {:degrees => 'fahrenheit'})
      #   # => GET /weather.json?degrees=fahrenheit
      #
      # == Failure or missing data
      # A failure to find the requested object raises a ResourceNotFound exception.
      #
      #   Inventory.find
      #   # => raises ResourceNotFound
      def find(options = {})
        prefix_options, query_options = split_options(options[:params])
        path = singleton_path(prefix_options, query_options)

        super(:one, options.merge(from: path, params: prefix_options))
      end
    end
    # Deletes the resource from the remote service.
    #
    # ==== Examples
    #   weather = Weather.find
    #   weather.destroy
    #   Weather.find # 404 (Resource Not Found)
    def destroy
      connection.delete(singleton_path, self.class.headers)
    end


    protected
      # Update the resource on the remote service
      def _update
        connection.put(singleton_path(prefix_options), encode, self.class.headers).tap do |response|
          load_attributes_from_response(response)
        end
      end

      # Create (i.e. \save to the remote service) the \new resource.
      def create
        connection.post(singleton_path, encode, self.class.headers).tap do |response|
          self.id = id_from_response(response)
          load_attributes_from_response(response)
        end
      end

    private
      def singleton_path(options = nil)
        self.class.singleton_path(options || prefix_options)
      end
  end
end
