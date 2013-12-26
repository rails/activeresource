module ActiveResource
  module Serialization
    extend ActiveSupport::Concern

    def to_json(options={})
      super(include_root_in_json ? { :root => self.class.element_name }.merge(options) : options)
    end

    def to_xml(options={})
      super({ :root => self.class.element_name }.merge(options))
    end

    # Returns the serialized string representation of the resource in the configured
    # serialization format specified in ActiveResource::Base.format. The options
    # applicable depend on the configured encoding format.
    def encode(options={})
      send("to_#{self.class.format.extension}", options)
    end





  end
end
