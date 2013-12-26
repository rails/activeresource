module ActiveResource
  module ConnectionHandling

    # Gets the URI of the REST resources to map for this class. The site variable is required for
    # Active Resource's mapping to work.
    def site
      # Not using superclass_delegating_reader because don't want subclasses to modify superclass instance
      #
      # With superclass_delegating_reader
      #
      #   Parent.site = 'https://anonymous@test.com'
      #   Subclass.site # => 'https://anonymous@test.com'
      #   Subclass.site.user = 'david'
      #   Parent.site # => 'https://david@test.com'
      #
      # Without superclass_delegating_reader (expected behavior)
      #
      #   Parent.site = 'https://anonymous@test.com'
      #   Subclass.site # => 'https://anonymous@test.com'
      #   Subclass.site.user = 'david' # => TypeError: can't modify frozen object
      #
      if defined?(@site)
        @site
      elsif superclass != Object && superclass.site
        superclass.site.dup.freeze
      end
    end

    # Sets the URI of the REST resources to map for this class to the value in the +site+ argument.
    # The site variable is required for Active Resource's mapping to work.
    def site=(site)
      @connection = nil
      if site.nil?
        @site = nil
      else
        @site = create_site_uri_from(site)
        @user = URI.parser.unescape(@site.user) if @site.user
        @password = URI.parser.unescape(@site.password) if @site.password
      end
    end

    # Gets the \proxy variable if a proxy is required
    def proxy
      # Not using superclass_delegating_reader. See +site+ for explanation
      if defined?(@proxy)
        @proxy
      elsif superclass != Object && superclass.proxy
        superclass.proxy.dup.freeze
      end
    end

    # Sets the URI of the http proxy to the value in the +proxy+ argument.
    def proxy=(proxy)
      @connection = nil
      @proxy = proxy.nil? ? nil : create_proxy_uri_from(proxy)
    end

    # Gets the \user for REST HTTP authentication.
    def user
      # Not using superclass_delegating_reader. See +site+ for explanation
      if defined?(@user)
        @user
      elsif superclass != Object && superclass.user
        superclass.user.dup.freeze
      end
    end

    # Sets the \user for REST HTTP authentication.
    def user=(user)
      @connection = nil
      @user = user
    end

    # Gets the \password for REST HTTP authentication.
    def password
      # Not using superclass_delegating_reader. See +site+ for explanation
      if defined?(@password)
        @password
      elsif superclass != Object && superclass.password
        superclass.password.dup.freeze
      end
    end

    # Sets the \password for REST HTTP authentication.
    def password=(password)
      @connection = nil
      @password = password
    end

    def auth_type
      if defined?(@auth_type)
        @auth_type
      end
    end

    def auth_type=(auth_type)
      @connection = nil
      @auth_type = auth_type
    end

    # Sets the number of seconds after which requests to the REST API should time out.
    def timeout=(timeout)
      @connection = nil
      @timeout = timeout
    end

    # Gets the number of seconds after which requests to the REST API should time out.
    def timeout
      if defined?(@timeout)
        @timeout
      elsif superclass != Object && superclass.timeout
        superclass.timeout
      end
    end

    # Options that will get applied to an SSL connection.
    #
    # * <tt>:key</tt> - An OpenSSL::PKey::RSA or OpenSSL::PKey::DSA object.
    # * <tt>:cert</tt> - An OpenSSL::X509::Certificate object as client certificate
    # * <tt>:ca_file</tt> - Path to a CA certification file in PEM format. The file can contain several CA certificates.
    # * <tt>:ca_path</tt> - Path of a CA certification directory containing certifications in PEM format.
    # * <tt>:verify_mode</tt> - Flags for server the certification verification at beginning of SSL/TLS session. (OpenSSL::SSL::VERIFY_NONE or OpenSSL::SSL::VERIFY_PEER is acceptable)
    # * <tt>:verify_callback</tt> - The verify callback for the server certification verification.
    # * <tt>:verify_depth</tt> - The maximum depth for the certificate chain verification.
    # * <tt>:cert_store</tt> - OpenSSL::X509::Store to verify peer certificate.
    # * <tt>:ssl_timeout</tt> -The SSL timeout in seconds.
    def ssl_options=(options)
      @connection   = nil
      @ssl_options  = options
    end

    # Returns the SSL options hash.
    def ssl_options
      if defined?(@ssl_options)
        @ssl_options
      elsif superclass != Object && superclass.ssl_options
        superclass.ssl_options
      end
    end

    # An instance of ActiveResource::Connection that is the base \connection to the remote service.
    # The +refresh+ parameter toggles whether or not the \connection is refreshed at every request
    # or not (defaults to <tt>false</tt>).
    def connection(refresh = false)
      if defined?(@connection) || superclass == Object
        @connection = Connection.new(site, format) if refresh || @connection.nil?
        @connection.proxy = proxy if proxy
        @connection.user = user if user
        @connection.password = password if password
        @connection.auth_type = auth_type if auth_type
        @connection.timeout = timeout if timeout
        @connection.ssl_options = ssl_options if ssl_options
        @connection
      else
        superclass.connection
      end
    end

    def headers
      Thread.current["active.resource.headers.#{self.object_id}"] ||= {}

      if superclass != Object && superclass.headers
        Thread.current["active.resource.headers.#{self.object_id}"] = superclass.headers.merge(Thread.current["active.resource.headers.#{self.object_id}"])
      else
        Thread.current["active.resource.headers.#{self.object_id}"]
      end
    end


    # Sets the format that attributes are sent and received in from a mime type reference:
    #
    #   Person.format = :json
    #   Person.find(1) # => GET /people/1.json
    #
    #   Person.format = ActiveResource::Formats::XmlFormat
    #   Person.find(1) # => GET /people/1.xml
    #
    # Default format is <tt>:json</tt>.
    def format=(mime_type_reference_or_format)
      format = mime_type_reference_or_format.is_a?(Symbol) ?
          ActiveResource::Formats[mime_type_reference_or_format] : mime_type_reference_or_format

      self._format = format
      connection.format = format if site
    end

    # Returns the current format, default is ActiveResource::Formats::JsonFormat.
    def format
      self._format || ActiveResource::Formats::JsonFormat
    end

    # Sets the parser to use when a collection is returned.  The parser must be Enumerable.
    def collection_parser=(parser_instance)
      parser_instance = parser_instance.constantize if parser_instance.is_a?(String)
      self._collection_parser = parser_instance
    end

    def collection_parser
      self._collection_parser || ActiveResource::Collection
    end



    attr_writer :element_name

    def element_name
      @element_name ||= model_name.element
    end

    attr_writer :collection_name

    def collection_name
      @collection_name ||= ActiveSupport::Inflector.pluralize(element_name)
    end


    # Gets the \prefix for a resource's nested URL (e.g., <tt>prefix/collectionname/1.json</tt>)
    # This method is regenerated at runtime based on what the \prefix is set to.
    def prefix(options={})
      default = site.path
      default << '/' unless default[-1..-1] == '/'
      # generate the actual method based on the current site path
      self.prefix = default
      prefix(options)
    end

    # An attribute reader for the source string for the resource path \prefix. This
    # method is regenerated at runtime based on what the \prefix is set to.
    def prefix_source
      prefix # generate #prefix and #prefix_source methods first
      prefix_source
    end

    # Sets the \prefix for a resource's nested URL (e.g., <tt>prefix/collectionname/1.json</tt>).
    # Default value is <tt>site.path</tt>.
    def prefix=(value = '/')
      # Replace :placeholders with '#{embedded options[:lookups]}'
      prefix_call = value.gsub(/:\w+/) { |key| "\#{URI.parser.escape options[#{key}].to_s}" }

      # Clear prefix parameters in case they have been cached
      @prefix_parameters = nil

      silence_warnings do
        # Redefine the new methods.
        instance_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            def prefix_source() "#{value}" end
            def prefix(options={}) "#{prefix_call}" end
        RUBY_EVAL
      end
    rescue Exception => e
      logger.error "Couldn't set prefix: #{e}\n  #{code}" if logger
      raise
    end

    alias_method :set_prefix, :prefix=  #:nodoc:

    alias_method :set_element_name, :element_name=  #:nodoc:
    alias_method :set_collection_name, :collection_name=  #:nodoc:

    def format_extension
      include_format_in_path ? ".#{format.extension}" : ""
    end

    # Gets the element path for the given ID in +id+. If the +query_options+ parameter is omitted, Rails
    # will split from the \prefix options.
    #
    # ==== Options
    # +prefix_options+ - A \hash to add a \prefix to the request for nested URLs (e.g., <tt>:account_id => 19</tt>
    # would yield a URL like <tt>/accounts/19/purchases.json</tt>).
    #
    # +query_options+ - A \hash to add items to the query string for the request.
    #
    # ==== Examples
    #   Post.element_path(1)
    #   # => /posts/1.json
    #
    #   class Comment < ActiveResource::Base
    #     self.site = "https://37s.sunrise.com/posts/:post_id"
    #   end
    #
    #   Comment.element_path(1, :post_id => 5)
    #   # => /posts/5/comments/1.json
    #
    #   Comment.element_path(1, :post_id => 5, :active => 1)
    #   # => /posts/5/comments/1.json?active=1
    #
    #   Comment.element_path(1, {:post_id => 5}, {:active => 1})
    #   # => /posts/5/comments/1.json?active=1
    #
    def element_path(id, prefix_options = {}, query_options = nil)
      check_prefix_options(prefix_options)

      prefix_options, query_options = split_options(prefix_options) if query_options.nil?
      "#{prefix(prefix_options)}#{collection_name}/#{URI.parser.escape id.to_s}#{format_extension}#{query_string(query_options)}"
    end

    # Gets the new element path for REST resources.
    #
    # ==== Options
    # * +prefix_options+ - A hash to add a prefix to the request for nested URLs (e.g., <tt>:account_id => 19</tt>
    # would yield a URL like <tt>/accounts/19/purchases/new.json</tt>).
    #
    # ==== Examples
    #   Post.new_element_path
    #   # => /posts/new.json
    #
    #   class Comment < ActiveResource::Base
    #     self.site = "https://37s.sunrise.com/posts/:post_id"
    #   end
    #
    #   Comment.collection_path(:post_id => 5)
    #   # => /posts/5/comments/new.json
    def new_element_path(prefix_options = {})
      "#{prefix(prefix_options)}#{collection_name}/new#{format_extension}"
    end

    # Gets the collection path for the REST resources. If the +query_options+ parameter is omitted, Rails
    # will split from the +prefix_options+.
    #
    # ==== Options
    # * +prefix_options+ - A hash to add a prefix to the request for nested URLs (e.g., <tt>:account_id => 19</tt>
    #   would yield a URL like <tt>/accounts/19/purchases.json</tt>).
    # * +query_options+ - A hash to add items to the query string for the request.
    #
    # ==== Examples
    #   Post.collection_path
    #   # => /posts.json
    #
    #   Comment.collection_path(:post_id => 5)
    #   # => /posts/5/comments.json
    #
    #   Comment.collection_path(:post_id => 5, :active => 1)
    #   # => /posts/5/comments.json?active=1
    #
    #   Comment.collection_path({:post_id => 5}, {:active => 1})
    #   # => /posts/5/comments.json?active=1
    #
    def collection_path(prefix_options = {}, query_options = nil)
      check_prefix_options(prefix_options)
      prefix_options, query_options = split_options(prefix_options) if query_options.nil?
      "#{prefix(prefix_options)}#{collection_name}#{format_extension}#{query_string(query_options)}"
    end


    private

    # Accepts a URI and creates the site URI from that.
    def create_site_uri_from(site)
      site.is_a?(URI) ? site.dup : URI.parse(site)
    end

    # Accepts a URI and creates the proxy URI from that.
    def create_proxy_uri_from(proxy)
      proxy.is_a?(URI) ? proxy.dup : URI.parse(proxy)
    end

    # contains a set of the current prefix parameters.
    def prefix_parameters
      @prefix_parameters ||= prefix_source.scan(/:\w+/).map { |key| key[1..-1].to_sym }.to_set
    end

    # Builds the query string for the request.
    def query_string(options)
      "?#{options.to_query}" unless options.nil? || options.empty?
    end

    # split an option hash into two hashes, one containing the prefix options,
    # and the other containing the leftovers.
    def split_options(options = {})
      prefix_options, query_options = {}, {}

      (options || {}).each do |key, value|
        next if key.blank? || !key.respond_to?(:to_sym)
        (prefix_parameters.include?(key.to_sym) ? prefix_options : query_options)[key.to_sym] = value
      end

      [ prefix_options, query_options ]
    end



  end
end