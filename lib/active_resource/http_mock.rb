# frozen_string_literal: true

require "active_support/core_ext/kernel/reporting"
require "active_support/core_ext/object/inclusion"

module ActiveResource
  class InvalidRequestError < StandardError; end # :nodoc:

  # One thing that has always been a pain with remote web services is testing. The HttpMock
  # class makes it easy to test your Active Resource models by creating a set of mock responses to specific
  # requests.
  #
  # To test your Active Resource model, you simply call the ActiveResource::HttpMock.respond_to
  # method with an attached block. The block declares a set of URIs with expected input, and the output
  # each request should return. The passed in block has any number of entries in the following generalized
  # format:
  #
  #   mock.http_method(path, request_headers = {}, body = nil, status = 200, response_headers = {})
  #
  # * <tt>http_method</tt> - The HTTP method to listen for. This can be +get+, +post+, +patch+, +put+, +delete+ or
  #   +head+.
  # * <tt>path</tt> - A string, starting with a "/", defining the URI that is expected to be
  #   called.
  # * <tt>request_headers</tt> - Headers that are expected along with the request. This argument uses a
  #   hash format, such as <tt>{ "Content-Type" => "application/json" }</tt>. This mock will only trigger
  #   if your tests sends a request with identical headers.
  # * <tt>body</tt> - The data to be returned. This should be a string of Active Resource parseable content,
  #   such as Json.
  # * <tt>status</tt> - The HTTP response code, as an integer, to return with the response.
  # * <tt>response_headers</tt> - Headers to be returned with the response. Uses the same hash format as
  #   <tt>request_headers</tt> listed above.
  #
  # In order for a mock to deliver its content, the incoming request must match by the <tt>http_method</tt>,
  # +path+ and <tt>request_headers</tt>. If no match is found an +InvalidRequestError+ exception
  # will be raised showing you what request it could not find a response for and also what requests and response
  # pairs have been recorded so you can create a new mock for that request.
  #
  # ==== Example
  #   def setup
  #     @matz  = { :person => { :id => 1, :name => "Matz" } }.to_json
  #     ActiveResource::HttpMock.respond_to do |mock|
  #       mock.post   "/people.json",   {}, @matz, 201, "Location" => "/people/1.json"
  #       mock.get    "/people/1.json", {}, @matz
  #       mock.put    "/people/1.json", {}, nil, 204
  #       mock.delete "/people/1.json", {}, nil, 200
  #     end
  #   end
  #
  #   def test_get_matz
  #     person = Person.find(1)
  #     assert_equal "Matz", person.name
  #   end
  #
  # Each method can also accept a block. The mock will yield an
  # ActiveResource::Request instance to the block it handles a matching request.
  #
  #   def setup
  #     @matz = { person: { id: 1, name: "Matz" } }
  #
  #     ActiveResource::HttpMock.respond_to do |mock|
  #       mock.get "/people.json", omit_query_params: true do |request|
  #         if request.path.split("?").includes?("name=Matz")
  #           { people: [ @matz ] }.to_json
  #         else
  #           { people: [] }.to_json
  #         end
  #       end
  #     end
  #   end
  #
  #   def test_get_matz
  #     people = Person.where(name: "Matz")
  #     assert_equal [ "Matz" ], people.map(&:name)
  #   end
  #
  # When a block is passed to the mock, it ignores the +body+, +status+, and +response_headers+ arguments.
  class HttpMock
    HTTP_METHODS = Connection::HTTP_METHODS.invert.freeze # :nodoc:

    class Responder # :nodoc:
      def initialize(responses)
        @responses = responses
      end

      [ :post, :patch, :put, :get, :delete, :head ].each do |method|
        # def post(path, request_headers = {}, body = nil, status = 200, response_headers = {}, options: {})
        #   @responses[Request.new(:post, path, nil, request_headers, options)] = Response.new(body || "", status, response_headers)
        # end
        module_eval <<-EOE, __FILE__, __LINE__ + 1
          def #{method}(path, request_headers = {}, body = nil, status = 200, response_headers = {}, options = {}, &response)
            options  = body if response
            request  = Request.new(:#{method}, path, nil, request_headers, options)
            response = Response.new(body || "", status, response_headers) unless response

            delete_duplicate_responses(request)

            @responses << [request, response]
          end
        EOE
      end

    private
      def delete_duplicate_responses(request)
        @responses.delete_if { |r| r[0] == request }
      end
    end

    class << self
      # Returns an array of all request objects that have been sent to the mock. You can use this to check
      # if your model actually sent an HTTP request.
      #
      # ==== Example
      #   def setup
      #     @matz  = { :person => { :id => 1, :name => "Matz" } }.to_json
      #     ActiveResource::HttpMock.respond_to do |mock|
      #       mock.get "/people/1.json", {}, @matz
      #     end
      #   end
      #
      #   def test_should_request_remote_service
      #     person = Person.find(1)  # Call the remote service
      #
      #     # This request object has the same HTTP method and path as declared by the mock
      #     expected_request = ActiveResource::Request.new(:get, "/people/1.json")
      #
      #     # Assert that the mock received, and responded to, the expected request from the model
      #     assert ActiveResource::HttpMock.requests.include?(expected_request)
      #   end
      def requests
        @@requests ||= []
      end

      # Returns the list of requests and their mocked responses. Look up a
      # response for a request using <tt>responses.assoc(request)</tt>.
      def responses
        @@responses ||= []
      end

      # Accepts a block which declares a set of requests and responses for the HttpMock to respond to in
      # the following format:
      #
      #   mock.http_method(path, request_headers = {}, body = nil, status = 200, response_headers = {})
      #
      # === Example
      #
      #   @matz  = { :person => { :id => 1, :name => "Matz" } }.to_json
      #   ActiveResource::HttpMock.respond_to do |mock|
      #     mock.post   "/people.json",   {}, @matz, 201, "Location" => "/people/1.json"
      #     mock.get    "/people/1.json", {}, @matz
      #     mock.put    "/people/1.json", {}, nil, 204
      #     mock.delete "/people/1.json", {}, nil, 200
      #   end
      #
      # Alternatively, accepts a hash of <tt>{Request => Response}</tt> pairs allowing you to generate
      # these the following format:
      #
      #   ActiveResource::Request.new(method, path, body, request_headers)
      #   ActiveResource::Response.new(body, status, response_headers)
      #
      # === Example
      #
      # Request.new(method, path, nil, request_headers)
      #
      #   @matz  = { :person => { :id => 1, :name => "Matz" } }.to_json
      #
      #   create_matz      = ActiveResource::Request.new(:post, '/people.json', @matz, {})
      #   created_response = ActiveResource::Response.new("", 201, {"Location" => "/people/1.json"})
      #   get_matz         = ActiveResource::Request.new(:get, '/people/1.json', nil)
      #   ok_response      = ActiveResource::Response.new("", 200, {})
      #
      #   pairs = {create_matz => created_response, get_matz => ok_response}
      #
      #   ActiveResource::HttpMock.respond_to(pairs)
      #
      # Note, by default, every time you call +respond_to+, any previous request and response pairs stored
      # in HttpMock will be deleted giving you a clean slate to work on.
      #
      # If you want to override this behavior, pass in +false+ as the last argument to +respond_to+
      #
      # === Example
      #
      #   ActiveResource::HttpMock.respond_to do |mock|
      #     mock.get("/people/1", {}, "JSON1")
      #   end
      #   ActiveResource::HttpMock.responses.length #=> 1
      #
      #   ActiveResource::HttpMock.respond_to(false) do |mock|
      #     mock.get("/people/2", {}, "JSON2")
      #   end
      #   ActiveResource::HttpMock.responses.length #=> 2
      #
      # This also works with passing in generated pairs of requests and responses, again, just pass in false
      # as the last argument:
      #
      # === Example
      #
      #   ActiveResource::HttpMock.respond_to do |mock|
      #     mock.get("/people/1", {}, "JSON1")
      #   end
      #   ActiveResource::HttpMock.responses.length #=> 1
      #
      #   get_matz         = ActiveResource::Request.new(:get, '/people/1.json', nil)
      #   ok_response      = ActiveResource::Response.new("", 200, {})
      #
      #   pairs = {get_matz => ok_response}
      #
      #   ActiveResource::HttpMock.respond_to(pairs, false)
      #   ActiveResource::HttpMock.responses.length #=> 2
      #
      #   # If you add a response with an existing request, it will be replaced
      #
      #   fail_response      = ActiveResource::Response.new("", 404, {})
      #   pairs = {get_matz => fail_response}
      #
      #   ActiveResource::HttpMock.respond_to(pairs, false)
      #   ActiveResource::HttpMock.responses.length #=> 2
      #
      def respond_to(*args) # :yields: mock
        pairs = args.first || {}
        reset! if args.last.class != FalseClass

        if block_given?
          yield Responder.new(responses)
        else
          delete_responses_to_replace pairs.to_a
          responses.concat pairs.to_a
          Responder.new(responses)
        end
      end

      def delete_responses_to_replace(new_responses)
        new_responses.each { |nr|
          request_to_remove = nr[0]
          @@responses = responses.delete_if { |r| r[0] == request_to_remove }
        }
      end

      # Deletes all logged requests and responses.
      def reset!
        requests.clear
        responses.clear
      end

      # Enables all ActiveResource::Connection instances to use real
      # Net::HTTP instance instead of a mock.
      def enable_net_connection!
        @@net_connection_enabled = true
      end

      # Sets all ActiveResource::Connection to use HttpMock instances.
      def disable_net_connection!
        @@net_connection_enabled = false
      end

      # Checks if real requests can be used instead of the default mock used in tests.
      def net_connection_enabled?
        if defined?(@@net_connection_enabled)
          @@net_connection_enabled
        else
          @@net_connection_enabled = false
        end
      end

      def net_connection_disabled?
        !net_connection_enabled?
      end
    end

    # body?       methods
    { true  => %w[post patch put],
      false => %w[get delete head] }.each do |has_body, methods|
      methods.each do |method|
        # def post(path, body, headers, options = {})
        #   request = ActiveResource::Request.new(:post, path, body, headers, options)
        #
        #   process(request)
        # end
        module_eval <<-EOE, __FILE__, __LINE__ + 1
          def #{method}(path, #{'body, ' if has_body}headers, options = {})
            request = ActiveResource::Request.new(:#{method}, path, #{has_body ? 'body, ' : 'nil, '}headers, options)

            process(request)
          end
        EOE
      end
    end

    def request(http) # :nodoc:
      request = Request.new(HTTP_METHODS[http.class], http.path, nil, http.each_capitalized.to_h)
      request.body = http.body if http.request_body_permitted?

      process(request)
    end

    def process(request) # :nodoc:
      self.class.requests << request
      if response = self.class.responses.assoc(request)
        response = response[1]
        response = response.call(request) if response.respond_to?(:call)

        Response.wrap(response)
      else
        raise InvalidRequestError.new("Could not find a response recorded for #{request} - Responses recorded are: #{inspect_responses}")
      end
    end

    def initialize(site) # :nodoc:
      @site = site
    end

    def inspect_responses # :nodoc:
      self.class.responses.map { |r| r[0].to_s }.inspect
    end
  end

  class Request
    attr_accessor :path, :method, :body, :headers

    def initialize(method, path, body = nil, headers = {}, options = {})
      @method, @path, @body, @headers, @options = method, path, body, headers.transform_keys(&:downcase), options
    end

    def ==(req)
      same_path?(req) && method == req.method && headers_match?(req)
    end

    def to_s
      "<#{method.to_s.upcase}: #{path} [#{headers}] (#{body})>"
    end

    # Removes query parameters from the path.
    #
    # @return [String] the path without query parameters
    def remove_query_params_from_path
      path.split("?").first
    end

    private
      def same_path?(req)
        if @options && @options[:omit_query_in_path]
          remove_query_params_from_path == req.remove_query_params_from_path
        else
          path == req.path
        end
      end

      def headers_match?(req)
        # Ignore format header on equality if it's not defined
        format_header = ActiveResource::Connection::HTTP_FORMAT_HEADER_NAMES[method].downcase
        if headers[format_header].present? || req.headers[format_header].blank?
          headers == req.headers
        else
          headers.dup.merge(format_header => req.headers[format_header]) == req.headers
        end
      end
  end

  class Response
    attr_accessor :body, :message, :code, :headers

    def self.wrap(response) # :nodoc:
      case response
      when self then response
      when String then new(response)
      else new(nil)
      end
    end

    def initialize(body, message = 200, headers = {})
      @body, @message, @headers = body, message.to_s, headers
      @code = @message[0, 3].to_i

      resp_cls = Net::HTTPResponse::CODE_TO_OBJ[@code.to_s]
      if resp_cls && !resp_cls.body_permitted?
        @body = nil
      end

      self["Content-Length"] = @body.nil? ? "0" : body.size.to_s
    end

    # Returns true if code is 2xx,
    # false otherwise.
    def success?
      code.in?(200..299)
    end

    def [](key)
      headers[key]
    end

    def []=(key, value)
      headers[key] = value
    end

    # Returns true if the other is a Response with an equal body, equal message
    # and equal headers. Otherwise it returns false.
    def ==(other)
      if other.is_a?(Response)
        other.body == body && other.message == message && other.headers == headers
      else
        false
      end
    end
  end

  class Connection
    private
      silence_warnings do
        def http
          if unstub_http?
            @http = configure_http(new_http)
          elsif stub_http?
            @http = http_stub
          end
          @http ||= http_stub
        end

        def http_stub
          HttpMock.new(@site)
        end

        def unstub_http?
          HttpMock.net_connection_enabled? && (!defined?(@http) || @http.kind_of?(HttpMock))
        end

        def stub_http?
          HttpMock.net_connection_disabled? && (!defined?(@http) || @http.kind_of?(Net::HTTP))
        end
      end
  end
end
