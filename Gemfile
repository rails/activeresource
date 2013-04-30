source 'https://rubygems.org'

gemspec

gem 'activesupport', github: 'rails/rails', branch: 'master'
gem 'activemodel', github: 'rails/rails', branch: 'master'
gem 'rails-observers', github: 'rails/rails-observers', branch: 'master'

# Add your own local bundler stuff
local_gemfile = File.dirname(__FILE__) + "/.Gemfile"
instance_eval File.read local_gemfile if File.exists? local_gemfile

platforms :ruby do
  gem 'json'
  gem 'yajl-ruby'
  gem 'nokogiri', '>= 1.4.5'
  
  group :test do
    gem 'ruby-prof'
  end
end
