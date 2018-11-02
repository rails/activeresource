# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}" }

branch = ENV.fetch("BRANCH", "master")
gem "activesupport", github: "rails/rails", branch: branch
gem "activemodel", github: "rails/rails", branch: branch
gem "activejob", github: "rails/rails", branch: branch

gemspec

platform :mri do
  group :test do
    gem "ruby-prof"
  end
end
