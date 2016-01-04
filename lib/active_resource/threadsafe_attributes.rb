module ThreadsafeAttributes
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def threadsafe_attribute(*attrs)
      attrs.each do |attr|
        define_method attr do
          get_threadsafe_attribute(attr)
        end

        define_method "#{attr}=" do |value|
          set_threadsafe_attribute(attr, value)
        end

        define_method "#{attr}_defined?" do
          threadsafe_attribute_defined?(attr)
        end
      end
    end
  end

  private

  def get_threadsafe_attribute(name)
    if threadsafe_attribute_defined_by_thread?(name, Thread.current)
      get_threadsafe_attribute_by_thread(name, Thread.current)
    elsif threadsafe_attribute_defined_by_thread?(name, Thread.main)
      value = get_threadsafe_attribute_by_thread(name, Thread.main)
      value = value.dup if value
      set_threadsafe_attribute_by_thread(name, value, Thread.current)
      value
    end
  end

  def set_threadsafe_attribute(name, value)
    set_threadsafe_attribute_by_thread(name, value, Thread.current)
    unless threadsafe_attribute_defined_by_thread?(name, Thread.main)
      set_threadsafe_attribute_by_thread(name, value, Thread.main)
    end
  end

  def threadsafe_attribute_defined?(name)
    threadsafe_attribute_defined_by_thread?(name, Thread.current) || ((Thread.current != Thread.main) && threadsafe_attribute_defined_by_thread?(name, Thread.main))
  end

  def get_threadsafe_attribute_by_thread(name, thread)
    thread["active.resource.#{name}.#{self.object_id}"]
  end

  def set_threadsafe_attribute_by_thread(name, value, thread)
    thread["active.resource.#{name}.#{self.object_id}.defined"] = true
    thread["active.resource.#{name}.#{self.object_id}"] = value
  end

  def threadsafe_attribute_defined_by_thread?(name, thread)
    thread["active.resource.#{name}.#{self.object_id}.defined"]
  end

end
