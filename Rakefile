#!/usr/bin/env rake
require 'rake/testtask'
require 'rake/packagetask'
require 'rubygems/package_task'

desc "Default Task"
task :default => [ :test ]

# Run the unit tests

Rake::TestTask.new { |t|
  t.libs << "test"
  t.pattern = 'test/**/*_test.rb'
  t.warning = true
  t.verbose = true
}

namespace :test do
  task :isolated do
    ruby = File.join(*RbConfig::CONFIG.values_at('bindir', 'RUBY_INSTALL_NAME'))
    activesupport_path = "#{File.dirname(__FILE__)}/../activesupport/lib"
    Dir.glob("test/**/*_test.rb").all? do |file|
      sh(ruby, '-w', "-Ilib:test:#{activesupport_path}", file)
    end or raise "Failures"
  end
end

task :lines do
  lines, codelines, total_lines, total_codelines = 0, 0, 0, 0

  FileList["lib/active_resource/**/*.rb"].each do |file_name|
    next if file_name =~ /vendor/
    f = File.open(file_name)

    while line = f.gets
      lines += 1
      next if line =~ /^\s*$/
      next if line =~ /^\s*#/
      codelines += 1
    end
    puts "L: #{sprintf("%4d", lines)}, LOC #{sprintf("%4d", codelines)} | #{file_name}"

    total_lines     += lines
    total_codelines += codelines

    lines, codelines = 0, 0
  end

  puts "Total: Lines #{total_lines}, LOC #{total_codelines}"
end

# Publishing ------------------------------------------------------

spec = eval(File.read('activeresource.gemspec'))
gem = "pkg/activeresource-#{spec.version}.gem"
tag = "v#{spec.version}"

desc "Release to rubygems.org"
task :release => [:ensure_clean_state, :tag, :push]

task(:tag) { sh "git tag #{tag} && git push --tags" }

task(:push => :repackage) { sh "gem push #{gem}" }
task(:install => :repackage) { sh "gem install #{gem}" }
Gem::PackageTask.new(spec) { |p| p.gem_spec = spec }

task :ensure_clean_state do
  unless `git status -s`.strip.empty?
    abort "[ABORTING] `git status` reports a dirty tree. Make sure all changes are committed"
  end

  unless ENV['SKIP_TAG'] || `git tag | grep #{tag}`.strip.empty?
    abort "[ABORTING] `git tag` shows that #{tag} already exists. Has this version already\n"\
      "           been released? Git tagging can be skipped by setting SKIP_TAG=1"
  end
end
