# frozen_string_literal: true

#--
# Copyright (c) 2006-2012 David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require "uri"

require "active_support"
require "active_model"
require "active_resource/exceptions"
require "active_resource/version"

module ActiveResource
  extend ActiveSupport::Autoload

  URI_PARSER = defined?(URI::RFC2396_PARSER) ? URI::RFC2396_PARSER : URI::RFC2396_Parser.new

  autoload :Base
  autoload :Callbacks
  autoload :Connection
  autoload :CustomMethods
  autoload :Formats
  autoload :HttpMock
  autoload :Schema
  autoload :Singleton
  autoload :InheritingHash
  autoload :Validations
  autoload :Collection
  autoload :WhereClause

  if ActiveSupport::VERSION::STRING >= "7.1"
    def self.deprecator
      @deprecator ||= ActiveSupport::Deprecation.new(VERSION::STRING, "ActiveResource")
    end
  else
    def self.deprecator
      ActiveSupport::Deprecation
    end
  end
end

require "active_resource/railtie" if defined?(Rails.application)
