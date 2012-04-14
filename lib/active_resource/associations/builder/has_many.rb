module ActiveResource::Associations::Builder 
  class HasMany < Association
    self.macro = :has_many

    def build
      validate_options
      reflection = model.create_reflection(self.class.macro, name, options)
      model.defines_has_many_finder_method(reflection.name, reflection.klass)
      return reflection
    end
  end
end
