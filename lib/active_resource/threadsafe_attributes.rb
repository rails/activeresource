require 'active_support/core_ext/object/duplicable'

module ThreadsafeAttributes
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def threadsafe_attribute(*attrs)
      main_thread = Thread.main # remember this, because it could change after forking

      attrs.each do |attr|
        define_method attr do
          get_threadsafe_attribute(attr, main_thread)
        end

        define_method "#{attr}=" do |value|
          set_threadsafe_attribute(attr, value, main_thread)
        end

        define_method "#{attr}_defined?" do
          threadsafe_attribute_defined?(attr, main_thread)
        end
      end
    end
  end

  private

  def get_threadsafe_attribute(name, main_thread)
    if threadsafe_attribute_defined_by_thread?(name, Thread.current)
      get_threadsafe_attribute_by_thread(name, Thread.current)
    elsif threadsafe_attribute_defined_by_thread?(name, main_thread)
      value = get_threadsafe_attribute_by_thread(name, main_thread)
      value = value.dup if value.duplicable?
      set_threadsafe_attribute_by_thread(name, value, Thread.current)
      value
    end
  end

  def set_threadsafe_attribute(name, value, main_thread)
    set_threadsafe_attribute_by_thread(name, value, Thread.current)
    unless threadsafe_attribute_defined_by_thread?(name, main_thread)
      set_threadsafe_attribute_by_thread(name, value, main_thread)
    end
  end

  def threadsafe_attribute_defined?(name, main_thread)
    threadsafe_attribute_defined_by_thread?(name, Thread.current) || ((Thread.current != main_thread) && threadsafe_attribute_defined_by_thread?(name, main_thread))
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
