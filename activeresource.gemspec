# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("../lib", __FILE__)
require "active_resource/version"

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "activeresource"
  s.version     = ActiveResource::VERSION::STRING
  s.summary     = "REST modeling framework (part of Rails)."
  s.description = "REST on Rails. Wrap your RESTful web app with Ruby classes and work with them like Active Record models."
  s.license     = "MIT"

  s.author      = "David Heinemeier Hansson"
  s.email       = "david@loudthinking.com"
  s.homepage    = "http://www.rubyonrails.org"

  s.files = Dir["MIT-LICENSE", "README.rdoc", "lib/**/*"]
  s.require_path = "lib"

  s.extra_rdoc_files = %w( README.rdoc )
  s.rdoc_options.concat ["--main",  "README.rdoc"]

  s.required_ruby_version = ">= 2.2.2"

  s.add_dependency("activesupport", ">= 5.0", "< 7")
  s.add_dependency("activemodel", ">= 5.0", "< 7")
  s.add_dependency("activemodel-serializers-xml", "~> 1.0")

  s.add_development_dependency("rake")
  s.add_development_dependency("mocha", ">= 0.13.0")
  s.add_development_dependency("rexml")
end
