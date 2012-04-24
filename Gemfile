source 'https://rubygems.org'

gemspec

gem 'activesupport', :git => "git://github.com/rails/rails.git"
gem 'activemodel', :git => "git://github.com/rails/rails.git"

group :doc do
  # The current sdoc cannot generate GitHub links due
  # to a bug, but the PR that fixes it has been there
  # for some weeks unapplied. As a temporary solution
  # this is our own fork with the fix.
  gem 'sdoc', :git => 'git://github.com/fxn/sdoc.git'
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
