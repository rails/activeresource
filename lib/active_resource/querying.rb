module ActiveResource
  module Querying

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
        when :all   then find_every(options)
        when :first then find_every(options).first
        when :last  then find_every(options).last
        when :one   then find_one(options)
        else             find_single(scope, options)
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

  end
end