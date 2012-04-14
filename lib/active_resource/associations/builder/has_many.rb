module ActiveResource::Associations::Builder 
  class HasMany < Association
    self.macro = :has_many

    def build
      validate_options
      model.create_reflection(self.class.macro, name, options).tap do |reflection|
        model.defines_has_many_finder_method(reflection.name, reflection.klass)
      end
    end
  end
end
