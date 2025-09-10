# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("../lib", __FILE__)
require "active_resource/version"

Gem::Specification.new do |s|
  version = ActiveResource::VERSION::STRING
  s.platform    = Gem::Platform::RUBY
  s.name        = "activeresource"
  s.version     = version
  s.summary     = "REST modeling framework (part of Rails)."
  s.description = "REST on Rails. Wrap your RESTful web app with Ruby classes and work with them like Active Record models."
  s.license     = "MIT"

  s.author      = "David Heinemeier Hansson"
  s.email       = "david@loudthinking.com"
  s.homepage    = "http://www.rubyonrails.org"

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/rails/activeresource/issues",
    "changelog_uri"     => "https://github.com/rails/activeresource/releases/tag/v#{version}",
    "documentation_uri" => "http://rubydoc.info/gems/activeresource",
    "source_code_uri"   => "https://github.com/rails/activeresource/tree/v#{version}",
    "rubygems_mfa_required" => "true"
  }

  s.files = Dir["MIT-LICENSE", "README.md", "lib/**/*"]
  s.require_path = "lib"

  s.required_ruby_version = ">= 2.6.0"

  s.add_dependency("activesupport", ">= 6.0")
  s.add_dependency("activemodel", ">= 6.0")
  s.add_dependency("activemodel-serializers-xml", "~> 1.0")

  s.add_development_dependency("rake")
  s.add_development_dependency("mocha", ">= 0.13.0")
  s.add_development_dependency("rexml")
end
