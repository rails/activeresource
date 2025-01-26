# frozen_string_literal: true

module ActiveResource
  module Casings
    extend ActiveSupport::Autoload

    autoload :CamelcaseCasing, "active_resource/casings/camelcase_casing"
    autoload :NoneCasing, "active_resource/casings/none_casing"
    autoload :UnderscoreCasing, "active_resource/casings/underscore_casing"

    # Lookup the casing class from a reference symbol. Example:
    #
    #   ActiveResource::Casings[:camelcase]   # => ActiveResource::Casings::CamelcaseCasing
    #   ActiveResource::Casings[:none]        # => ActiveResource::Casings::NoneCasing
    #   ActiveResource::Casings[:underscore]  # => ActiveResource::Casings::UnderscoreCasing
    def self.[](name)
      const_get(ActiveSupport::Inflector.camelize(name.to_s) + "Casing")
    end
  end
end
