require 'active_support/core_ext/benchmark'
require 'active_support/core_ext/uri'
require 'active_support/core_ext/object/inclusion'
require 'net/https'
require 'date'
require 'time'
require 'uri'

module ActiveResource
  # Class to handle connections to remote web services.
  # This class is used by ActiveResource::Base to interface with REST
  # services.
  class Connection

    HTTP_FORMAT_HEADER_NAMES = {  :get => 'Accept',
      :put => 'Content-Type',
      :post => 'Content-Type',
      :patch => 'Content-Type',
      :delete => 'Accept',
      :head => 'Accept'
    }

    attr_reader :site, :user, :password, :auth_type, :timeout, :open_timeout, :read_timeout, :proxy, :ssl_options
    attr_accessor :format

    class << self
      def requests
        @@requests ||= []
      end
    end

    # The +site+ parameter is required and will set the +site+
    # attribute to the URI for the remote resource service.
    def initialize(site, format = ActiveResource::Formats::JsonFormat)
      raise ArgumentError, 'Missing site URI' unless site
      @proxy = @user = @password = nil
      self.site = site
      self.format = format
    end

    # Set URI for remote service.
    def site=(site)
      @site = site.is_a?(URI) ? site : URI.parse(site)
      @ssl_options ||= {} if @site.is_a?(URI::HTTPS)
      @user = URI.parser.unescape(@site.user) if @site.user
      @password = URI.parser.unescape(@site.password) if @site.password
    end

    # Set the proxy for remote service.
    def proxy=(proxy)
      @proxy = proxy.is_a?(URI) ? proxy : URI.parse(proxy)
    end

    # Sets the user for remote service.
    def user=(user)
      @user = user
    end

    # Sets the password for remote service.
    def password=(password)
      @password = password
    end

    # Sets the auth type for remote service.
    def auth_type=(auth_type)
      @auth_type = legitimize_auth_type(auth_type)
    end

    # Sets the number of seconds after which HTTP requests to the remote service should time out.
    def timeout=(timeout)
      @timeout = timeout
    end

    # Sets the number of seconds after which HTTP connects to the remote service should time out.
    def open_timeout=(timeout)
      @open_timeout = timeout
    end

    # Sets the number of seconds after which HTTP read requests to the remote service should time out.
    def read_timeout=(timeout)
      @read_timeout = timeout
    end

    # Hash of options applied to Net::HTTP instance when +site+ protocol is 'https'.
    def ssl_options=(options)
      @ssl_options = options
    end

    # Executes a GET request.
    # Used to get (find) resources.
    def get(path, headers = {})
      with_auth { request(:get, path, build_request_headers(headers, :get, self.site.merge(path))) }
    end

    # Executes a DELETE request (see HTTP protocol documentation if unfamiliar).
    # Used to delete resources.
    def delete(path, headers = {})
      with_auth { request(:delete, path, build_request_headers(headers, :delete, self.site.merge(path))) }
    end

    # Executes a PATCH request (see HTTP protocol documentation if unfamiliar).
    # Used to update resources.
    def patch(path, body = '', headers = {})
      with_auth { request(:patch, path, body.to_s, build_request_headers(headers, :patch, self.site.merge(path))) }
    end

    # Executes a PUT request (see HTTP protocol documentation if unfamiliar).
    # Used to update resources.
    def put(path, body = '', headers = {})
      with_auth { request(:put, path, body.to_s, build_request_headers(headers, :put, self.site.merge(path))) }
    end

    # Executes a POST request.
    # Used to create new resources.
    def post(path, body = '', headers = {})
      with_auth { request(:post, path, body.to_s, build_request_headers(headers, :post, self.site.merge(path))) }
    end

    # Executes a HEAD request.
    # Used to obtain meta-information about resources, such as whether they exist and their size (via response headers).
    def head(path, headers = {})
      with_auth { request(:head, path, build_request_headers(headers, :head, self.site.merge(path))) }
    end

    private
      # Makes a request to the remote service.
      def request(method, path, *arguments)
        result = ActiveSupport::Notifications.instrument("request.active_resource") do |payload|
          payload[:method]      = method
          payload[:request_uri] = "#{site.scheme}://#{site.host}:#{site.port}#{path}"
          payload[:params]      = get_request_params(arguments[0]) if arguments[0].is_a? String
          payload[:result]      = http.send(method, path, *arguments)
        end
        handle_response(result)
      rescue Timeout::Error => e
        raise TimeoutError.new(e.message)
      rescue OpenSSL::SSL::SSLError => e
        raise SSLError.new(e.message)
      end

      # Handles response and error codes from the remote service.
      def handle_response(response)
        case response.code.to_i
          when 301, 302, 303, 307
            raise(Redirection.new(response))
          when 200...400
            response
          when 400
            raise(BadRequest.new(response))
          when 401
            raise(UnauthorizedAccess.new(response))
          when 403
            raise(ForbiddenAccess.new(response))
          when 404
            raise(ResourceNotFound.new(response))
          when 405
            raise(MethodNotAllowed.new(response))
          when 409
            raise(ResourceConflict.new(response))
          when 410
            raise(ResourceGone.new(response))
          when 422
            raise(ResourceInvalid.new(response))
          when 401...500
            raise(ClientError.new(response))
          when 500...600
            raise(ServerError.new(response))
          else
            raise(ConnectionError.new(response, "Unknown response code: #{response.code}"))
        end
      end

      # Creates new Net::HTTP instance for communication with the
      # remote service and resources.
      def http
        configure_http(new_http)
      end

      def new_http
        if @proxy
          user = URI.parser.unescape(@proxy.user) if @proxy.user
          password = URI.parser.unescape(@proxy.password) if @proxy.password
          Net::HTTP.new(@site.host, @site.port, @proxy.host, @proxy.port, user, password)
        else
          Net::HTTP.new(@site.host, @site.port)
        end
      end

      def configure_http(http)
        apply_ssl_options(http).tap do |https|
          # Net::HTTP timeouts default to 60 seconds.
          if defined? @timeout
            https.open_timeout = @timeout
            https.read_timeout = @timeout
          end
          https.open_timeout = @open_timeout if defined?(@open_timeout)
          https.read_timeout = @read_timeout if defined?(@read_timeout)
        end
      end

      def apply_ssl_options(http)
        http.tap do |https|
          # Skip config if site is already a https:// URI.
          if defined? @ssl_options
            http.use_ssl = true

            # All the SSL options have corresponding http settings.
            @ssl_options.each { |key, value| http.send "#{key}=", value }
          end
        end
      end

      def default_header
        @default_header ||= {}
      end

      # Builds headers for request to remote service.
      def build_request_headers(headers, http_method, uri)
        authorization_header(http_method, uri).update(default_header).update(http_format_header(http_method)).update(headers)
      end

      def response_auth_header
        @response_auth_header ||= ""
      end

      def with_auth
        retried ||= false
        yield
      rescue UnauthorizedAccess => e
        raise if retried || auth_type != :digest
        @response_auth_header = e.response['WWW-Authenticate']
        retried = true
        retry
      end

      def authorization_header(http_method, uri)
        if @user || @password
          if auth_type == :digest
            { 'Authorization' => digest_auth_header(http_method, uri) }
          else
            { 'Authorization' => 'Basic ' + ["#{@user}:#{@password}"].pack('m').delete("\r\n") }
          end
        else
          {}
        end
      end

      def digest_auth_header(http_method, uri)
        params = extract_params_from_response

        request_uri = uri.path
        request_uri << "?#{uri.query}" if uri.query

        ha1 = Digest::MD5.hexdigest("#{@user}:#{params['realm']}:#{@password}")
        ha2 = Digest::MD5.hexdigest("#{http_method.to_s.upcase}:#{request_uri}")

        params.merge!('cnonce' => client_nonce)
        request_digest = Digest::MD5.hexdigest([ha1, params['nonce'], "0", params['cnonce'], params['qop'], ha2].join(":"))
        "Digest #{auth_attributes_for(uri, request_digest, params)}"
      end

      def client_nonce
        Digest::MD5.hexdigest("%x" % (Time.now.to_i + rand(65535)))
      end

      def extract_params_from_response
        params = {}
        if response_auth_header =~ /^(\w+) (.*)/
          $2.gsub(/(\w+)="(.*?)"/) { params[$1] = $2 }
        end
        params
      end

      def auth_attributes_for(uri, request_digest, params)
        auth_attrs =
          [
            %Q(username="#{@user}"),
            %Q(realm="#{params['realm']}"),
            %Q(qop="#{params['qop']}"),
            %Q(uri="#{uri.path}"),
            %Q(nonce="#{params['nonce']}"),
            %Q(nc="0"),
            %Q(cnonce="#{params['cnonce']}"),
            %Q(response="#{request_digest}")]

        auth_attrs << %Q(opaque="#{params['opaque']}") unless params['opaque'].blank?
        auth_attrs.join(", ")
      end

      def http_format_header(http_method)
        {HTTP_FORMAT_HEADER_NAMES[http_method] => format.mime_type}
      end

      def legitimize_auth_type(auth_type)
        return :basic if auth_type.nil?
        auth_type = auth_type.to_sym
        auth_type.in?([:basic, :digest]) ? auth_type : :basic
      end

      def get_request_params(params_string)
        case format
          when ActiveResource::Formats::JsonFormat
            JSON.parse(params_string)
          when ActiveResource::Formats::XmlFormat
            Hash.from_xml(params_string)
        end
      end
  end
end
