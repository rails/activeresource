require 'active_support'
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/kernel/reporting'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/module/aliasing'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/to_query'
require 'active_support/core_ext/object/duplicable'
require 'set'
require 'uri'

require 'active_support/core_ext/uri'
require 'active_resource/connection'
require 'active_resource/formats'
require 'active_resource/schema'
require 'active_resource/log_subscriber'
require 'active_resource/associations'
require 'active_resource/reflection'
require 'active_resource/threadsafe_attributes'

module ActiveResource
  # ActiveResource::Base is the main class for mapping RESTful resources as models in a Rails application.
  #
  # For an outline of what Active Resource is capable of, see its {README}[link:files/activeresource/README_rdoc.html].
  #
  # == Automated mapping
  #
  # Active Resource objects represent your RESTful resources as manipulatable Ruby objects. To map resources
  # to Ruby objects, Active Resource only needs a class name that corresponds to the resource name (e.g., the class
  # Person maps to the resources people, very similarly to Active Record) and a +site+ value, which holds the
  # URI of the resources.
  #
  #   class Person < ActiveResource::Base
  #     self.site = "https://api.people.com"
  #   end
  #
  # Now the Person class is mapped to RESTful resources located at <tt>https://api.people.com/people/</tt>, and
  # you can now use Active Resource's life cycle methods to manipulate resources. In the case where you already have
  # an existing model with the same name as the desired RESTful resource you can set the +element_name+ value.
  #
  #   class PersonResource < ActiveResource::Base
  #     self.site = "https://api.people.com"
  #     self.element_name = "person"
  #   end
  #
  # If your Active Resource object is required to use an HTTP proxy you can set the +proxy+ value which holds a URI.
  #
  #   class PersonResource < ActiveResource::Base
  #     self.site = "https://api.people.com"
  #     self.proxy = "https://user:password@proxy.people.com:8080"
  #   end
  #
  #
  # == Life cycle methods
  #
  # Active Resource exposes methods for creating, finding, updating, and deleting resources
  # from REST web services.
  #
  #   ryan = Person.new(:first => 'Ryan', :last => 'Daigle')
  #   ryan.save                # => true
  #   ryan.id                  # => 2
  #   Person.exists?(ryan.id)  # => true
  #   ryan.exists?             # => true
  #
  #   ryan = Person.find(1)
  #   # Resource holding our newly created Person object
  #
  #   ryan.first = 'Rizzle'
  #   ryan.save                # => true
  #
  #   ryan.destroy             # => true
  #
  # As you can see, these are very similar to Active Record's life cycle methods for database records.
  # You can read more about each of these methods in their respective documentation.
  #
  # === Custom REST methods
  #
  # Since simple CRUD/life cycle methods can't accomplish every task, Active Resource also supports
  # defining your own custom REST methods. To invoke them, Active Resource provides the <tt>get</tt>,
  # <tt>post</tt>, <tt>put</tt> and <tt>delete</tt> methods where you can specify a custom REST method
  # name to invoke.
  #
  #   # POST to the custom 'register' REST method, i.e. POST /people/new/register.json.
  #   Person.new(:name => 'Ryan').post(:register)
  #   # => { :id => 1, :name => 'Ryan', :position => 'Clerk' }
  #
  #   # PUT an update by invoking the 'promote' REST method, i.e. PUT /people/1/promote.json?position=Manager.
  #   Person.find(1).put(:promote, :position => 'Manager')
  #   # => { :id => 1, :name => 'Ryan', :position => 'Manager' }
  #
  #   # GET all the positions available, i.e. GET /people/positions.json.
  #   Person.get(:positions)
  #   # => [{:name => 'Manager'}, {:name => 'Clerk'}]
  #
  #   # DELETE to 'fire' a person, i.e. DELETE /people/1/fire.json.
  #   Person.find(1).delete(:fire)
  #
  # For more information on using custom REST methods, see the
  # ActiveResource::CustomMethods documentation.
  #
  # == Validations
  #
  # You can validate resources client side by overriding validation methods in the base class.
  #
  #   class Person < ActiveResource::Base
  #      self.site = "https://api.people.com"
  #      protected
  #        def validate
  #          errors.add("last", "has invalid characters") unless last =~ /[a-zA-Z]*/
  #        end
  #   end
  #
  # See the ActiveResource::Validations documentation for more information.
  #
  # == Authentication
  #
  # Many REST APIs require authentication. The HTTP spec describes two ways to
  # make requests with a username and password (see RFC 2617).
  #
  # Basic authentication simply sends a username and password along with HTTP
  # requests. These sensitive credentials are sent unencrypted, visible to
  # any onlooker, so this scheme should only be used with SSL.
  #
  # Digest authentication sends a crytographic hash of the username, password,
  # HTTP method, URI, and a single-use secret key provided by the server.
  # Sensitive credentials aren't visible to onlookers, so digest authentication
  # doesn't require SSL. However, this doesn't mean the connection is secure!
  # Just the username and password.
  #
  # (You really, really want to use SSL. There's little reason not to.)
  #
  # === Picking an authentication scheme
  #
  # Basic authentication is the default. To switch to digest authentication,
  # set +auth_type+ to +:digest+:
  #
  #    class Person < ActiveResource::Base
  #      self.auth_type = :digest
  #    end
  #
  # === Setting the username and password
  #
  # Set +user+ and +password+ on the class, or include them in the +site+ URL.
  #
  #    class Person < ActiveResource::Base
  #      # Set user and password directly:
  #      self.user = "ryan"
  #      self.password = "password"
  #
  #      # Or include them in the site:
  #      self.site = "https://ryan:password@api.people.com"
  #    end
  #
  # === Certificate Authentication
  #
  # You can also authenticate using an X509 certificate. <tt>See ssl_options=</tt> for all options.
  #
  #    class Person < ActiveResource::Base
  #      self.site = "https://secure.api.people.com/"
  #
  #      File.open(pem_file_path, 'rb') do |pem_file|
  #        self.ssl_options = {
  #          cert:        OpenSSL::X509::Certificate.new(pem_file),
  #          key:         OpenSSL::PKey::RSA.new(pem_file),
  #          ca_path:     "/path/to/OpenSSL/formatted/CA_Certs",
  #          verify_mode: OpenSSL::SSL::VERIFY_PEER }
  #      end
  #    end
  #
  #
  # == Errors & Validation
  #
  # Error handling and validation is handled in much the same manner as you're used to seeing in
  # Active Record. Both the response code in the HTTP response and the body of the response are used to
  # indicate that an error occurred.
  #
  # === Resource errors
  #
  # When a GET is requested for a resource that does not exist, the HTTP <tt>404</tt> (Resource Not Found)
  # response code will be returned from the server which will raise an ActiveResource::ResourceNotFound
  # exception.
  #
  #   # GET https://api.people.com/people/999.json
  #   ryan = Person.find(999) # 404, raises ActiveResource::ResourceNotFound
  #
  #
  # <tt>404</tt> is just one of the HTTP error response codes that Active Resource will handle with its own exception. The
  # following HTTP response codes will also result in these exceptions:
  #
  # * 200..399 - Valid response. No exceptions, other than these redirects:
  # * 301, 302, 303, 307 - ActiveResource::Redirection
  # * 400 - ActiveResource::BadRequest
  # * 401 - ActiveResource::UnauthorizedAccess
  # * 403 - ActiveResource::ForbiddenAccess
  # * 404 - ActiveResource::ResourceNotFound
  # * 405 - ActiveResource::MethodNotAllowed
  # * 409 - ActiveResource::ResourceConflict
  # * 410 - ActiveResource::ResourceGone
  # * 422 - ActiveResource::ResourceInvalid (rescued by save as validation errors)
  # * 401..499 - ActiveResource::ClientError
  # * 500..599 - ActiveResource::ServerError
  # * Other - ActiveResource::ConnectionError
  #
  # These custom exceptions allow you to deal with resource errors more naturally and with more precision
  # rather than returning a general HTTP error. For example:
  #
  #   begin
  #     ryan = Person.find(my_id)
  #   rescue ActiveResource::ResourceNotFound
  #     redirect_to :action => 'not_found'
  #   rescue ActiveResource::ResourceConflict, ActiveResource::ResourceInvalid
  #     redirect_to :action => 'new'
  #   end
  #
  # When a GET is requested for a nested resource and you don't provide the prefix_param
  # an ActiveResource::MissingPrefixParam will be raised.
  #
  #  class Comment < ActiveResource::Base
  #    self.site = "https://someip.com/posts/:post_id"
  #  end
  #
  #  Comment.find(1)
  #  # => ActiveResource::MissingPrefixParam: post_id prefix_option is missing
  #
  # === Validation errors
  #
  # Active Resource supports validations on resources and will return errors if any of these validations fail
  # (e.g., "First name can not be blank" and so on). These types of errors are denoted in the response by
  # a response code of <tt>422</tt> and an JSON or XML representation of the validation errors. The save operation will
  # then fail (with a <tt>false</tt> return value) and the validation errors can be accessed on the resource in question.
  #
  #   ryan = Person.find(1)
  #   ryan.first # => ''
  #   ryan.save  # => false
  #
  #   # When
  #   # PUT https://api.people.com/people/1.xml
  #   # or
  #   # PUT https://api.people.com/people/1.json
  #   # is requested with invalid values, the response is:
  #   #
  #   # Response (422):
  #   # <errors><error>First cannot be empty</error></errors>
  #   # or
  #   # {"errors":{"first":["cannot be empty"]}}
  #   #
  #
  #   ryan.errors.invalid?(:first)  # => true
  #   ryan.errors.full_messages     # => ['First cannot be empty']
  #
  # For backwards-compatibility with older endpoints, the following formats are also supported in JSON responses:
  #
  #   # {"errors":['First cannot be empty']}
  #   #   This was the required format for previous versions of ActiveResource
  #   # {"first":["cannot be empty"]}
  #   #   This was the default format produced by respond_with in ActionController <3.2.1
  #
  # Parsing either of these formats will result in a deprecation warning.
  #
  # Learn more about Active Resource's validation features in the ActiveResource::Validations documentation.
  #
  # === Timeouts
  #
  # Active Resource relies on HTTP to access RESTful APIs and as such is inherently susceptible to slow or
  # unresponsive servers. In such cases, your Active Resource method calls could \timeout. You can control the
  # amount of time before Active Resource times out with the +timeout+ variable.
  #
  #   class Person < ActiveResource::Base
  #     self.site = "https://api.people.com"
  #     self.timeout = 5
  #   end
  #
  # This sets the +timeout+ to 5 seconds. You can adjust the +timeout+ to a value suitable for the RESTful API
  # you are accessing. It is recommended to set this to a reasonably low value to allow your Active Resource
  # clients (especially if you are using Active Resource in a Rails application) to fail-fast (see
  # http://en.wikipedia.org/wiki/Fail-fast) rather than cause cascading failures that could incapacitate your
  # server.
  #
  # When a \timeout occurs, an ActiveResource::TimeoutError is raised. You should rescue from
  # ActiveResource::TimeoutError in your Active Resource method calls.
  #
  # Internally, Active Resource relies on Ruby's Net::HTTP library to make HTTP requests. Setting +timeout+
  # sets the <tt>read_timeout</tt> of the internal Net::HTTP instance to the same value. The default
  # <tt>read_timeout</tt> is 60 seconds on most Ruby implementations.
  #
  # Active Resource also supports distinct +open_timeout+ (time to connect) and +read_timeout+ (how long to
  # wait for an upstream response). This is inline with supported +Net::HTTP+ timeout configuration and allows
  # for finer control of client timeouts depending on context.
  #
  #   class Person < ActiveResource::Base
  #     self.site = "https://api.people.com"
  #     self.open_timeout = 2
  #     self.read_timeout = 10
  #   end
  class Base
    ##
    # :singleton-method:
    # The logger for diagnosing and tracing Active Resource calls.
    cattr_accessor :logger

    class_attribute :_format
    class_attribute :_collection_parser
    class_attribute :include_format_in_path
    self.include_format_in_path = true

    class_attribute :connection_class
    self.connection_class = Connection

    class << self
      include ThreadsafeAttributes
      threadsafe_attribute :_headers, :_connection, :_user, :_password, :_site, :_proxy

      # Creates a schema for this resource - setting the attributes that are
      # known prior to fetching an instance from the remote system.
      #
      # The schema helps define the set of <tt>known_attributes</tt> of the
      # current resource.
      #
      # There is no need to specify a schema for your Active Resource. If
      # you do not, the <tt>known_attributes</tt> will be guessed from the
      # instance attributes returned when an instance is fetched from the
      # remote system.
      #
      # example:
      #   class Person < ActiveResource::Base
      #     schema do
      #       # define each attribute separately
      #       attribute 'name', :string
      #
      #       # or use the convenience methods and pass >=1 attribute names
      #       string  'eye_color', 'hair_color'
      #       integer 'age'
      #       float   'height', 'weight'
      #
      #       # unsupported types should be left as strings
      #       # overload the accessor methods if you need to convert them
      #       attribute 'created_at', 'string'
      #     end
      #   end
      #
      #   p = Person.new
      #   p.respond_to? :name   # => true
      #   p.respond_to? :age    # => true
      #   p.name                # => nil
      #   p.age                 # => nil
      #
      #   j = Person.find_by_name('John')
      #   <person><name>John</name><age>34</age><num_children>3</num_children></person>
      #   j.respond_to? :name   # => true
      #   j.respond_to? :age    # => true
      #   j.name                # => 'John'
      #   j.age                 # => '34'  # note this is a string!
      #   j.num_children        # => '3'  # note this is a string!
      #
      #   p.num_children        # => NoMethodError
      #
      # Attribute-types must be one of: <tt>string, text, integer, float, decimal, datetime, timestamp, time, date, binary, boolean</tt>
      #
      # Note: at present the attribute-type doesn't do anything, but stay
      # tuned...
      # Shortly it will also *cast* the value of the returned attribute.
      # ie:
      # j.age                 # => 34   # cast to an integer
      # j.weight              # => '65' # still a string!
      #
      def schema(&block)
        if block_given?
          schema_definition = Schema.new
          schema_definition.instance_eval(&block)

          # skip out if we didn't define anything
          return unless schema_definition.attrs.present?

          @schema ||= {}.with_indifferent_access
          @known_attributes ||= []

          schema_definition.attrs.each do |k,v|
            @schema[k] = v
            @known_attributes << k
          end

          schema
        else
          @schema ||= nil
        end
      end

      # Alternative, direct way to specify a <tt>schema</tt> for this
      # Resource. <tt>schema</tt> is more flexible, but this is quick
      # for a very simple schema.
      #
      # Pass the schema as a hash with the keys being the attribute-names
      # and the value being one of the accepted attribute types (as defined
      # in <tt>schema</tt>)
      #
      # example:
      #
      #   class Person < ActiveResource::Base
      #     schema = {'name' => :string, 'age' => :integer }
      #   end
      #
      # The keys/values can be strings or symbols. They will be converted to
      # strings.
      #
      def schema=(the_schema)
        unless the_schema.present?
          # purposefully nulling out the schema
          @schema = nil
          @known_attributes = []
          return
        end

        raise ArgumentError, "Expected a hash" unless the_schema.kind_of? Hash

        schema do
          the_schema.each {|k,v| attribute(k,v) }
        end
      end

      # Returns the list of known attributes for this resource, gathered
      # from the provided <tt>schema</tt>
      # Attributes that are known will cause your resource to return 'true'
      # when <tt>respond_to?</tt> is called on them. A known attribute will
      # return nil if not set (rather than <tt>MethodNotFound</tt>); thus
      # known attributes can be used with <tt>validates_presence_of</tt>
      # without a getter-method.
      def known_attributes
        @known_attributes ||= []
      end

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
        if _site_defined?
          _site
        elsif superclass != Object && superclass.site
          superclass.site.dup.freeze
        end
      end

      # Sets the URI of the REST resources to map for this class to the value in the +site+ argument.
      # The site variable is required for Active Resource's mapping to work.
      def site=(site)
        self._connection = nil
        if site.nil?
          self._site = nil
        else
          self._site = create_site_uri_from(site)
          self._user = URI.parser.unescape(_site.user) if _site.user
          self._password = URI.parser.unescape(_site.password) if _site.password
        end
      end

      # Gets the \proxy variable if a proxy is required
      def proxy
        # Not using superclass_delegating_reader. See +site+ for explanation
        if _proxy_defined?
          _proxy
        elsif superclass != Object && superclass.proxy
          superclass.proxy.dup.freeze
        end
      end

      # Sets the URI of the http proxy to the value in the +proxy+ argument.
      def proxy=(proxy)
        self._connection = nil
        self._proxy = proxy.nil? ? nil : create_proxy_uri_from(proxy)
      end

      # Gets the \user for REST HTTP authentication.
      def user
        # Not using superclass_delegating_reader. See +site+ for explanation
        if _user_defined?
          _user
        elsif superclass != Object && superclass.user
          superclass.user.dup.freeze
        end
      end

      # Sets the \user for REST HTTP authentication.
      def user=(user)
        self._connection = nil
        self._user = user
      end

      # Gets the \password for REST HTTP authentication.
      def password
        # Not using superclass_delegating_reader. See +site+ for explanation
        if _password_defined?
          _password
        elsif superclass != Object && superclass.password
          superclass.password.dup.freeze
        end
      end

      # Sets the \password for REST HTTP authentication.
      def password=(password)
        self._connection = nil
        self._password = password
      end

      def auth_type
        if defined?(@auth_type)
          @auth_type
        end
      end

      def auth_type=(auth_type)
        self._connection = nil
        @auth_type = auth_type
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

      # Sets the number of seconds after which requests to the REST API should time out.
      def timeout=(timeout)
        self._connection = nil
        @timeout = timeout
      end

      # Sets the number of seconds after which connection attempts to the REST API should time out.
      def open_timeout=(timeout)
        self._connection = nil
        @open_timeout = timeout
      end

      # Sets the number of seconds after which reads to the REST API should time out.
      def read_timeout=(timeout)
        self._connection = nil
        @read_timeout = timeout
      end

      # Gets the number of seconds after which requests to the REST API should time out.
      def timeout
        if defined?(@timeout)
          @timeout
        elsif superclass != Object && superclass.timeout
          superclass.timeout
        end
      end

      # Gets the number of seconds after which connection attempts to the REST API should time out.
      def open_timeout
        if defined?(@open_timeout)
          @open_timeout
        elsif superclass != Object && superclass.open_timeout
          superclass.open_timeout
        end
      end

      # Gets the number of seconds after which reads to the REST API should time out.
      def read_timeout
        if defined?(@read_timeout)
          @read_timeout
        elsif superclass != Object && superclass.read_timeout
          superclass.read_timeout
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
        self._connection = nil
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
        if _connection_defined? || superclass == Object
          self._connection = connection_class.new(site, format) if refresh || _connection.nil?
          _connection.proxy = proxy if proxy
          _connection.user = user if user
          _connection.password = password if password
          _connection.auth_type = auth_type if auth_type
          _connection.timeout = timeout if timeout
          _connection.open_timeout = open_timeout if open_timeout
          _connection.read_timeout = read_timeout if read_timeout
          _connection.ssl_options = ssl_options if ssl_options
          _connection
        else
          superclass.connection
        end
      end

      def headers
        headers_state = self._headers || {}
        if superclass != Object
          self._headers = superclass.headers.merge(headers_state)
        else
          headers_state
        end
      end

      attr_writer :element_name

      def element_name
        @element_name ||= model_name.element
      end

      attr_writer :collection_name

      def collection_name
        @collection_name ||= ActiveSupport::Inflector.pluralize(element_name)
      end

      attr_writer :primary_key

      def primary_key
        if defined?(@primary_key)
          @primary_key
        elsif superclass != Object && superclass.primary_key
          primary_key = superclass.primary_key
          return primary_key if primary_key.is_a?(Symbol)
          primary_key.dup.freeze
        else
          'id'
        end
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

      alias_method :set_primary_key, :primary_key=  #:nodoc:

      # Builds a new, unsaved record using the default values from the remote server so
      # that it can be used with RESTful forms.
      #
      # ==== Options
      # * +attributes+ - A hash that overrides the default values from the server.
      #
      # Returns the new resource instance.
      #
      def build(attributes = {})
        attrs = self.format.decode(connection.get("#{new_element_path(attributes)}", headers).body).merge(attributes)
        self.new(attrs)
      end

      # Creates a new resource instance and makes a request to the remote service
      # that it be saved, making it equivalent to the following simultaneous calls:
      #
      #   ryan = Person.new(:first => 'ryan')
      #   ryan.save
      #
      # Returns the newly created resource. If a failure has occurred an
      # exception will be raised (see <tt>save</tt>). If the resource is invalid and
      # has not been saved then <tt>valid?</tt> will return <tt>false</tt>,
      # while <tt>new?</tt> will still return <tt>true</tt>.
      #
      # ==== Examples
      #   Person.create(:name => 'Jeremy', :email => 'myname@nospam.com', :enabled => true)
      #   my_person = Person.find(:first)
      #   my_person.email # => myname@nospam.com
      #
      #   dhh = Person.create(:name => 'David', :email => 'dhh@nospam.com', :enabled => true)
      #   dhh.valid? # => true
      #   dhh.new?   # => false
      #
      #   # We'll assume that there's a validation that requires the name attribute
      #   that_guy = Person.create(:name => '', :email => 'thatguy@nospam.com', :enabled => true)
      #   that_guy.valid? # => false
      #   that_guy.new?   # => true
      def create(attributes = {})
        self.new(attributes).tap { |resource| resource.save }
      end

      # Core method for finding resources. Used similarly to Active Record's +find+ method.
      #
      # ==== Arguments
      # The first argument is considered to be the scope of the query. That is, how many
      # resources are returned from the request. It can be one of the following.
      #
      # * <tt>:one</tt> - Returns a single resource.
      # * <tt>:first</tt> - Returns the first resource found.
      # * <tt>:last</tt> - Returns the last resource found.
      # * <tt>:all</tt> - Returns every resource that matches the request.
      #
      # ==== Options
      #
      # * <tt>:from</tt> - Sets the path or custom method that resources will be fetched from.
      # * <tt>:params</tt> - Sets query and \prefix (nested URL) parameters.
      #
      # ==== Examples
      #   Person.find(1)
      #   # => GET /people/1.json
      #
      #   Person.find(:all)
      #   # => GET /people.json
      #
      #   Person.find(:all, :params => { :title => "CEO" })
      #   # => GET /people.json?title=CEO
      #
      #   Person.find(:first, :from => :managers)
      #   # => GET /people/managers.json
      #
      #   Person.find(:last, :from => :managers)
      #   # => GET /people/managers.json
      #
      #   Person.find(:all, :from => "/companies/1/people.json")
      #   # => GET /companies/1/people.json
      #
      #   Person.find(:one, :from => :leader)
      #   # => GET /people/leader.json
      #
      #   Person.find(:all, :from => :developers, :params => { :language => 'ruby' })
      #   # => GET /people/developers.json?language=ruby
      #
      #   Person.find(:one, :from => "/companies/1/manager.json")
      #   # => GET /companies/1/manager.json
      #
      #   StreetAddress.find(1, :params => { :person_id => 1 })
      #   # => GET /people/1/street_addresses/1.json
      #
      # == Failure or missing data
      # A failure to find the requested object raises a ResourceNotFound
      # exception if the find was called with an id.
      # With any other scope, find returns nil when no data is returned.
      #
      #   Person.find(1)
      #   # => raises ResourceNotFound
      #
      #   Person.find(:all)
      #   Person.find(:first)
      #   Person.find(:last)
      #   # => nil
      def find(*arguments)
        scope   = arguments.slice!(0)
        options = arguments.slice!(0) || {}

        case scope
        when :all
          find_every(options)
        when :first
          collection = find_every(options)
          collection && collection.first
        when :last
          collection = find_every(options)
          collection && collection.last
        when :one
          find_one(options)
        else
          find_single(scope, options)
        end
      end


      # A convenience wrapper for <tt>find(:first, *args)</tt>. You can pass
      # in all the same arguments to this method as you can to
      # <tt>find(:first)</tt>.
      def first(*args)
        find(:first, *args)
      end

      # A convenience wrapper for <tt>find(:last, *args)</tt>. You can pass
      # in all the same arguments to this method as you can to
      # <tt>find(:last)</tt>.
      def last(*args)
        find(:last, *args)
      end

      # This is an alias for find(:all). You can pass in all the same
      # arguments to this method as you can to <tt>find(:all)</tt>
      def all(*args)
        find(:all, *args)
      end

      def where(clauses = {})
        raise ArgumentError, "expected a clauses Hash, got #{clauses.inspect}" unless clauses.is_a? Hash
        find(:all, :params => clauses)
      end


      # Deletes the resources with the ID in the +id+ parameter.
      #
      # ==== Options
      # All options specify \prefix and query parameters.
      #
      # ==== Examples
      #   Event.delete(2) # sends DELETE /events/2
      #
      #   Event.create(:name => 'Free Concert', :location => 'Community Center')
      #   my_event = Event.find(:first) # let's assume this is event with ID 7
      #   Event.delete(my_event.id) # sends DELETE /events/7
      #
      #   # Let's assume a request to events/5/cancel.json
      #   Event.delete(params[:id]) # sends DELETE /events/5
      def delete(id, options = {})
        connection.delete(element_path(id, options), headers)
      end

      # Asserts the existence of a resource, returning <tt>true</tt> if the resource is found.
      #
      # ==== Examples
      #   Note.create(:title => 'Hello, world.', :body => 'Nothing more for now...')
      #   Note.exists?(1) # => true
      #
      #   Note.exists(1349) # => false
      def exists?(id, options = {})
        if id
          prefix_options, query_options = split_options(options[:params])
          path = element_path(id, prefix_options, query_options)
          response = connection.head(path, headers)
          response.code.to_i == 200
        end
        # id && !find_single(id, options).nil?
      rescue ActiveResource::ResourceNotFound, ActiveResource::ResourceGone
        false
      end

      private

        def check_prefix_options(prefix_options)
          p_options = HashWithIndifferentAccess.new(prefix_options)
          prefix_parameters.each do |p|
            raise(MissingPrefixParam, "#{p} prefix_option is missing") if p_options[p].blank?
          end
        end

        # Find every resource
        def find_every(options)
          begin
            case from = options[:from]
            when Symbol
              instantiate_collection(get(from, options[:params]), options[:params])
            when String
              path = "#{from}#{query_string(options[:params])}"
              instantiate_collection(format.decode(connection.get(path, headers).body) || [], options[:params])
            else
              prefix_options, query_options = split_options(options[:params])
              path = collection_path(prefix_options, query_options)
              instantiate_collection( (format.decode(connection.get(path, headers).body) || []), query_options, prefix_options )
            end
          rescue ActiveResource::ResourceNotFound
            # Swallowing ResourceNotFound exceptions and return nil - as per
            # ActiveRecord.
            nil
          end
        end

        # Find a single resource from a one-off URL
        def find_one(options)
          case from = options[:from]
          when Symbol
            instantiate_record(get(from, options[:params]))
          when String
            path = "#{from}#{query_string(options[:params])}"
            instantiate_record(format.decode(connection.get(path, headers).body))
          end
        end

        # Find a single resource from the default URL
        def find_single(scope, options)
          prefix_options, query_options = split_options(options[:params])
          path = element_path(scope, prefix_options, query_options)
          instantiate_record(format.decode(connection.get(path, headers).body), prefix_options)
        end

        def instantiate_collection(collection, original_params = {}, prefix_options = {})
          collection_parser.new(collection).tap do |parser|
            parser.resource_class  = self
            parser.original_params = original_params
          end.collect! { |record| instantiate_record(record, prefix_options) }
        end

        def instantiate_record(record, prefix_options = {})
          new(record, true).tap do |resource|
            resource.prefix_options = prefix_options
          end
        end


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

    attr_accessor :attributes #:nodoc:
    attr_accessor :prefix_options #:nodoc:

    # If no schema has been defined for the class (see
    # <tt>ActiveResource::schema=</tt>), the default automatic schema is
    # generated from the current instance's attributes
    def schema
      self.class.schema || self.attributes
    end

    # This is a list of known attributes for this resource. Either
    # gathered from the provided <tt>schema</tt>, or from the attributes
    # set on this instance after it has been fetched from the remote system.
    def known_attributes
      (self.class.known_attributes + self.attributes.keys.map(&:to_s)).uniq
    end


    # Constructor method for \new resources; the optional +attributes+ parameter takes a \hash
    # of attributes for the \new resource.
    #
    # ==== Examples
    #   my_course = Course.new
    #   my_course.name = "Western Civilization"
    #   my_course.lecturer = "Don Trotter"
    #   my_course.save
    #
    #   my_other_course = Course.new(:name => "Philosophy: Reason and Being", :lecturer => "Ralph Cling")
    #   my_other_course.save
    def initialize(attributes = {}, persisted = false)
      @attributes     = {}.with_indifferent_access
      @prefix_options = {}
      @persisted = persisted
      load(attributes, false, persisted)
    end

    # Returns a \clone of the resource that hasn't been assigned an +id+ yet and
    # is treated as a \new resource.
    #
    #   ryan = Person.find(1)
    #   not_ryan = ryan.clone
    #   not_ryan.new?  # => true
    #
    # Any active resource member attributes will NOT be cloned, though all other
    # attributes are. This is to prevent the conflict between any +prefix_options+
    # that refer to the original parent resource and the newly cloned parent
    # resource that does not exist.
    #
    #   ryan = Person.find(1)
    #   ryan.address = StreetAddress.find(1, :person_id => ryan.id)
    #   ryan.hash = {:not => "an ARes instance"}
    #
    #   not_ryan = ryan.clone
    #   not_ryan.new?            # => true
    #   not_ryan.address         # => NoMethodError
    #   not_ryan.hash            # => {:not => "an ARes instance"}
    def clone
      # Clone all attributes except the pk and any nested ARes
      cloned = Hash[attributes.reject {|k,v| k == self.class.primary_key || v.is_a?(ActiveResource::Base)}.map { |k, v| [k, v.clone] }]
      # Form the new resource - bypass initialize of resource with 'new' as that will call 'load' which
      # attempts to convert hashes into member objects and arrays into collections of objects. We want
      # the raw objects to be cloned so we bypass load by directly setting the attributes hash.
      resource = self.class.new({})
      resource.prefix_options = self.prefix_options
      resource.send :instance_variable_set, '@attributes', cloned
      resource
    end


    # Returns +true+ if this object hasn't yet been saved, otherwise, returns +false+.
    #
    # ==== Examples
    #   not_new = Computer.create(:brand => 'Apple', :make => 'MacBook', :vendor => 'MacMall')
    #   not_new.new? # => false
    #
    #   is_new = Computer.new(:brand => 'IBM', :make => 'Thinkpad', :vendor => 'IBM')
    #   is_new.new? # => true
    #
    #   is_new.save
    #   is_new.new? # => false
    #
    def new?
      !persisted?
    end
    alias :new_record? :new?

    # Returns +true+ if this object has been saved, otherwise returns +false+.
    #
    # ==== Examples
    #   persisted = Computer.create(:brand => 'Apple', :make => 'MacBook', :vendor => 'MacMall')
    #   persisted.persisted? # => true
    #
    #   not_persisted = Computer.new(:brand => 'IBM', :make => 'Thinkpad', :vendor => 'IBM')
    #   not_persisted.persisted? # => false
    #
    #   not_persisted.save
    #   not_persisted.persisted? # => true
    #
    def persisted?
      @persisted
    end

    # Gets the <tt>\id</tt> attribute of the resource.
    def id
      attributes[self.class.primary_key]
    end

    # Sets the <tt>\id</tt> attribute of the resource.
    def id=(id)
      attributes[self.class.primary_key] = id
    end

    # Test for equality. Resource are equal if and only if +other+ is the same object or
    # is an instance of the same class, is not <tt>new?</tt>, and has the same +id+.
    #
    # ==== Examples
    #   ryan = Person.create(:name => 'Ryan')
    #   jamie = Person.create(:name => 'Jamie')
    #
    #   ryan == jamie
    #   # => false (Different name attribute and id)
    #
    #   ryan_again = Person.new(:name => 'Ryan')
    #   ryan == ryan_again
    #   # => false (ryan_again is new?)
    #
    #   ryans_clone = Person.create(:name => 'Ryan')
    #   ryan == ryans_clone
    #   # => false (Different id attributes)
    #
    #   ryans_twin = Person.find(ryan.id)
    #   ryan == ryans_twin
    #   # => true
    #
    def ==(other)
      other.equal?(self) || (other.instance_of?(self.class) && other.id == id && other.prefix_options == prefix_options)
    end

    # Tests for equality (delegates to ==).
    def eql?(other)
      self == other
    end

    # Delegates to id in order to allow two resources of the same type and \id to work with something like:
    #   [(a = Person.find 1), (b = Person.find 2)] & [(c = Person.find 1), (d = Person.find 4)] # => [a]
    def hash
      id.hash
    end

    # Duplicates the current resource without saving it.
    #
    # ==== Examples
    #   my_invoice = Invoice.create(:customer => 'That Company')
    #   next_invoice = my_invoice.dup
    #   next_invoice.new? # => true
    #
    #   next_invoice.save
    #   next_invoice == my_invoice # => false (different id attributes)
    #
    #   my_invoice.customer   # => That Company
    #   next_invoice.customer # => That Company
    def dup
      self.class.new.tap do |resource|
        resource.attributes     = @attributes
        resource.prefix_options = @prefix_options
      end
    end

    # Saves (+POST+) or \updates (+PUT+) a resource. Delegates to +create+ if the object is \new,
    # +update+ if it exists. If the response to the \save includes a body, it will be assumed that this body
    # is Json for the final object as it looked after the \save (which would include attributes like +created_at+
    # that weren't part of the original submit).
    #
    # ==== Examples
    #   my_company = Company.new(:name => 'RoleModel Software', :owner => 'Ken Auer', :size => 2)
    #   my_company.new? # => true
    #   my_company.save # sends POST /companies/ (create)
    #
    #   my_company.new? # => false
    #   my_company.size = 10
    #   my_company.save # sends PUT /companies/1 (update)
    def save
      run_callbacks :save do
        new? ? create : update
      end
    end

    # Saves the resource.
    #
    # If the resource is new, it is created via +POST+, otherwise the
    # existing resource is updated via +PUT+.
    #
    # With <tt>save!</tt> validations always run. If any of them fail
    # ActiveResource::ResourceInvalid gets raised, and nothing is POSTed to
    # the remote system.
    # See ActiveResource::Validations for more information.
    #
    # There's a series of callbacks associated with <tt>save!</tt>. If any
    # of the <tt>before_*</tt> callbacks return +false+ the action is
    # cancelled and <tt>save!</tt> raises ActiveResource::ResourceInvalid.
    def save!
      save || raise(ResourceInvalid.new(self))
    end

    # Deletes the resource from the remote service.
    #
    # ==== Examples
    #   my_id = 3
    #   my_person = Person.find(my_id)
    #   my_person.destroy
    #   Person.find(my_id) # 404 (Resource Not Found)
    #
    #   new_person = Person.create(:name => 'James')
    #   new_id = new_person.id # => 7
    #   new_person.destroy
    #   Person.find(new_id) # 404 (Resource Not Found)
    def destroy
      run_callbacks :destroy do
        connection.delete(element_path, self.class.headers)
      end
    end

    # Evaluates to <tt>true</tt> if this resource is not <tt>new?</tt> and is
    # found on the remote service. Using this method, you can check for
    # resources that may have been deleted between the object's instantiation
    # and actions on it.
    #
    # ==== Examples
    #   Person.create(:name => 'Theodore Roosevelt')
    #   that_guy = Person.find(:first)
    #   that_guy.exists? # => true
    #
    #   that_lady = Person.new(:name => 'Paul Bean')
    #   that_lady.exists? # => false
    #
    #   guys_id = that_guy.id
    #   Person.delete(guys_id)
    #   that_guy.exists? # => false
    def exists?
      !new? && self.class.exists?(to_param, :params => prefix_options)
    end

    # Returns the serialized string representation of the resource in the configured
    # serialization format specified in ActiveResource::Base.format. The options
    # applicable depend on the configured encoding format.
    def encode(options={})
      send("to_#{self.class.format.extension}", options)
    end

    # A method to \reload the attributes of this object from the remote web service.
    #
    # ==== Examples
    #   my_branch = Branch.find(:first)
    #   my_branch.name # => "Wislon Raod"
    #
    #   # Another client fixes the typo...
    #
    #   my_branch.name # => "Wislon Raod"
    #   my_branch.reload
    #   my_branch.name # => "Wilson Road"
    def reload
      self.load(self.class.find(to_param, :params => @prefix_options).attributes, false, true)
    end

    # A method to manually load attributes from a \hash. Recursively loads collections of
    # resources. This method is called in +initialize+ and +create+ when a \hash of attributes
    # is provided.
    #
    # ==== Examples
    #   my_attrs = {:name => 'J&J Textiles', :industry => 'Cloth and textiles'}
    #   my_attrs = {:name => 'Marty', :colors => ["red", "green", "blue"]}
    #
    #   the_supplier = Supplier.find(:first)
    #   the_supplier.name # => 'J&M Textiles'
    #   the_supplier.load(my_attrs)
    #   the_supplier.name('J&J Textiles')
    #
    #   # These two calls are the same as Supplier.new(my_attrs)
    #   my_supplier = Supplier.new
    #   my_supplier.load(my_attrs)
    #
    #   # These three calls are the same as Supplier.create(my_attrs)
    #   your_supplier = Supplier.new
    #   your_supplier.load(my_attrs)
    #   your_supplier.save
    def load(attributes, remove_root = false, persisted = false)
      raise ArgumentError, "expected an attributes Hash, got #{attributes.inspect}" unless attributes.is_a?(Hash)
      @prefix_options, attributes = split_options(attributes)

      if attributes.keys.size == 1
        remove_root = self.class.element_name == attributes.keys.first.to_s
      end

      attributes = Formats.remove_root(attributes) if remove_root

      attributes.each do |key, value|
        @attributes[key.to_s] =
          case value
            when Array
              resource = nil
              value.map do |attrs|
                if attrs.is_a?(Hash)
                  resource ||= find_or_create_resource_for_collection(key)
                  resource.new(attrs, persisted)
                else
                  attrs.duplicable? ? attrs.dup : attrs
                end
              end
            when Hash
              resource = find_or_create_resource_for(key)
              resource.new(value, persisted)
            else
              value.duplicable? ? value.dup : value
          end
      end
      self
    end

    # Updates a single attribute and then saves the object.
    #
    # Note: <tt>Unlike ActiveRecord::Base.update_attribute</tt>, this method <b>is</b>
    # subject to normal validation routines as an update sends the whole body
    # of the resource in the request. (See Validations).
    #
    # As such, this method is equivalent to calling update_attributes with a single attribute/value pair.
    #
    # If the saving fails because of a connection or remote service error, an
    # exception will be raised. If saving fails because the resource is
    # invalid then <tt>false</tt> will be returned.
    def update_attribute(name, value)
      self.send("#{name}=".to_sym, value)
      self.save
    end

    # Updates this resource with all the attributes from the passed-in Hash
    # and requests that the record be saved.
    #
    # If the saving fails because of a connection or remote service error, an
    # exception will be raised. If saving fails because the resource is
    # invalid then <tt>false</tt> will be returned.
    #
    # Note: Though this request can be made with a partial set of the
    # resource's attributes, the full body of the request will still be sent
    # in the save request to the remote service.
    def update_attributes(attributes)
      load(attributes, false) && save
    end

    # For checking <tt>respond_to?</tt> without searching the attributes (which is faster).
    alias_method :respond_to_without_attributes?, :respond_to?

    # A method to determine if an object responds to a message (e.g., a method call). In Active Resource, a Person object with a
    # +name+ attribute can answer <tt>true</tt> to <tt>my_person.respond_to?(:name)</tt>, <tt>my_person.respond_to?(:name=)</tt>, and
    # <tt>my_person.respond_to?(:name?)</tt>.
    def respond_to?(method, include_priv = false)
      method_name = method.to_s
      if attributes.nil?
        super
      elsif known_attributes.include?(method_name)
        true
      elsif method_name =~ /(?:=|\?)$/ && attributes.include?($`)
        true
      else
        # super must be called at the end of the method, because the inherited respond_to?
        # would return true for generated readers, even if the attribute wasn't present
        super
      end
    end

    def to_json(options={})
      super(include_root_in_json ? { :root => self.class.element_name }.merge(options) : options)
    end

    def to_xml(options={})
      super({ :root => self.class.element_name }.merge(options))
    end

    protected
      def connection(refresh = false)
        self.class.connection(refresh)
      end

      # Update the resource on the remote service.
      def update
        run_callbacks :update do
          connection.put(element_path(prefix_options), encode, self.class.headers).tap do |response|
            load_attributes_from_response(response)
          end
        end
      end

      # Create (i.e., \save to the remote service) the \new resource.
      def create
        run_callbacks :create do
          connection.post(collection_path, encode, self.class.headers).tap do |response|
            self.id = id_from_response(response)
            load_attributes_from_response(response)
          end
        end
      end

      def load_attributes_from_response(response)
        if (response_code_allows_body?(response.code) &&
            (response['Content-Length'].nil? || response['Content-Length'] != "0") &&
            !response.body.nil? && response.body.strip.size > 0)
          load(self.class.format.decode(response.body), true, true)
          @persisted = true
        end
      end

      # Takes a response from a typical create post and pulls the ID out
      def id_from_response(response)
        response['Location'][/\/([^\/]*?)(\.\w+)?$/, 1] if response['Location']
      end

      def element_path(options = nil)
        self.class.element_path(to_param, options || prefix_options)
      end

      def new_element_path
        self.class.new_element_path(prefix_options)
      end

      def collection_path(options = nil)
        self.class.collection_path(options || prefix_options)
      end

    private

      def read_attribute_for_serialization(n)
        attributes[n]
      end

      # Determine whether the response is allowed to have a body per HTTP 1.1 spec section 4.4.1
      def response_code_allows_body?(c)
        !((100..199).include?(c) || [204,304].include?(c))
      end

      # Tries to find a resource for a given collection name; if it fails, then the resource is created
      def find_or_create_resource_for_collection(name)
        return reflections[name.to_sym].klass if reflections.key?(name.to_sym)
        find_or_create_resource_for(ActiveSupport::Inflector.singularize(name.to_s))
      end

      # Tries to find a resource in a non empty list of nested modules
      # if it fails, then the resource is created
      def find_or_create_resource_in_modules(resource_name, module_names)
        receiver = Object
        namespaces = module_names[0, module_names.size-1].map do |module_name|
          receiver = receiver.const_get(module_name)
        end
        const_args = [resource_name, false]
        if namespace = namespaces.reverse.detect { |ns| ns.const_defined?(*const_args) }
          namespace.const_get(*const_args)
        else
          create_resource_for(resource_name)
        end
      end

      # Tries to find a resource for a given name; if it fails, then the resource is created
      def find_or_create_resource_for(name)
        return reflections[name.to_sym].klass if reflections.key?(name.to_sym)
        resource_name = name.to_s.camelize

        const_args = [resource_name, false]
        if self.class.const_defined?(*const_args)
          self.class.const_get(*const_args)
        else
          ancestors = self.class.name.to_s.split("::")
          if ancestors.size > 1
            find_or_create_resource_in_modules(resource_name, ancestors)
          else
            if Object.const_defined?(*const_args)
              Object.const_get(*const_args)
            else
              create_resource_for(resource_name)
            end
          end
        end
      end

      # Create and return a class definition for a resource inside the current resource
      def create_resource_for(resource_name)
        resource = self.class.const_set(resource_name, Class.new(ActiveResource::Base))
        resource.prefix = self.class.prefix
        resource.site   = self.class.site
        resource
      end

      def split_options(options = {})
        self.class.__send__(:split_options, options)
      end

      def method_missing(method_symbol, *arguments) #:nodoc:
        method_name = method_symbol.to_s

        if method_name =~ /(=|\?)$/
          case $1
          when "="
            attributes[$`] = arguments.first
          when "?"
            attributes[$`]
          end
        else
          return attributes[method_name] if attributes.include?(method_name)
          # not set right now but we know about it
          return nil if known_attributes.include?(method_name)
          super
        end
      end
  end

  class Base
    extend ActiveModel::Naming
    extend ActiveResource::Associations

    include Callbacks, CustomMethods, Observing, Validations
    include ActiveModel::Conversion
    include ActiveModel::Serializers::JSON
    include ActiveModel::Serializers::Xml
    include ActiveResource::Reflection
  end

  ActiveSupport.run_load_hooks(:active_resource, Base)
end

