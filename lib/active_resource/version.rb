module ActiveResource
  module VERSION #:nodoc:
    # keeping this in lockstep with Rails version numbers
    MAJOR = 4
    MINOR = 2
    TINY  = 0

    # the PRE string is used to detect that we're using threadsafe in other gems
    PRE  = 'threadsafe'

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
  end
end
