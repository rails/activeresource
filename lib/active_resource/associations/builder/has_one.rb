module ActiveResource::Associations::Builder 
  class HasOne < Association
    self.macro = :has_one
    
    def build
      validate_options
      model.create_reflection(self.class.macro, name, options).tap do |reflection|
        model.defines_has_one_finder_method(reflection.name, reflection.klass)
      end
    end
  end
end
