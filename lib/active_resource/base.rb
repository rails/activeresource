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
  class Base
    ##
    # :singleton-method:
    # The logger for diagnosing and tracing Active Resource calls.
    cattr_accessor :logger

    class_attribute :_format
    class_attribute :_collection_parser
    class_attribute :include_format_in_path
    self.include_format_in_path = true

    attr_accessor :attributes #:nodoc:
    attr_accessor :prefix_options #:nodoc:

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


    private

      def read_attribute_for_serialization(n)
        attributes[n]
      end


  end

  class Base
    extend ActiveModel::Naming
    extend ActiveResource::Associations
    extend Querying
    extend ConnectionHandling

    include ActiveModel::Serializers::JSON
    include ActiveModel::Serializers::Xml
    include Serialization
    include ActiveModel::Conversion
    include ActiveResource::Reflection

    include Persistence, AttributeMethods
    include CoreMethods
    include Callbacks, CustomMethods, Observing, Validations
  end
end
