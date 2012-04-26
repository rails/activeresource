source 'https://rubygems.org'

gemspec

local_rails_path = File.expand_path(File.dirname(__FILE__) + '/../rails')
if File.exists?(local_rails_path)
  rails_gem_source = { :path => local_rails_path }
else
  rails_gem_source = { :git => "git://github.com/rails/rails.git" }
end

gem 'activesupport', rails_gem_source.dup
gem 'activemodel', rails_gem_source.dup
gem 'rake'

group :doc do
  # The current sdoc cannot generate GitHub links due
  # to a bug, but the PR that fixes it has been there
  # for some weeks unapplied. As a temporary solution
  # this is our own fork with the fix.
  gem 'sdoc',  :git => 'git://github.com/fxn/sdoc.git'
  gem 'RedCloth', '~> 4.2'
  gem 'w3c_validators'
end

# Add your own local bundler stuff
local_gemfile = File.dirname(__FILE__) + "/.Gemfile"
instance_eval File.read local_gemfile if File.exists? local_gemfile

platforms :mri do
  group :test do
    gem 'ruby-prof'
  end
end

platforms :ruby do
  gem 'json'
  gem 'yajl-ruby'
  gem 'nokogiri', '>= 1.4.5'
end

platforms :jruby do
  gem 'json'

  # This is needed by now to let tests work on JRuby
  # TODO: When the JRuby guys merge jruby-openssl in
  # jruby this will be removed
  gem 'jruby-openssl'
end
