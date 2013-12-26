module ActiveResource
  module Persistence
    extend ActiveSupport::Concern

    module ClassMethods

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

    def reload
      self.load(self.class.find(to_param, :params => @prefix_options).attributes, false, true)
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

    protected

    def load_attributes_from_response(response)
      if (response_code_allows_body?(response.code) &&
          (response['Content-Length'].nil? || response['Content-Length'] != "0") &&
          !response.body.nil? && response.body.strip.size > 0)
        load(self.class.format.decode(response.body), true, true)
        @persisted = true
      end
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

    # Takes a response from a typical create post and pulls the ID out
    def id_from_response(response)
      response['Location'][/\/([^\/]*?)(\.\w+)?$/, 1] if response['Location']
    end

    private

    # Determine whether the response is allowed to have a body per HTTP 1.1 spec section 4.4.1
    def response_code_allows_body?(c)
      !((100..199).include?(c) || [204,304].include?(c))
    end

  end
end