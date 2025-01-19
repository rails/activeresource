# frozen_string_literal: true

class StrongParameters
  def initialize(parameters = {})
    @parameters = parameters
    @permitted = false
  end

  def permitted?
    @permitted
  end

  def permit!
    @permitted = true
  end

  def to_hash
    @parameters.to_hash
  end
  alias to_h to_hash
end
