#!/usr/bin/env rake
require 'rake/testtask'
require 'rake/packagetask'
require 'rubygems/package_task'
require 'rdoc/task'
require 'sdoc'

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

spec = eval(File.read('activeresource.gemspec'))

Gem::PackageTask.new(spec) do |p|
  p.gem_spec = spec
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

desc "Generate documentation for the ActiveResource"
RDoc::Task.new do |rdoc|
  rdoc_main = File.read('README.rdoc')

  rdoc.rdoc_dir = 'doc/rdoc'
  rdoc.title    = "ActiveResource Documentation"

  rdoc.options << '-g' # SDoc flag, link methods to GitHub
  rdoc.options << '-f' << 'sdoc'

  rdoc.rdoc_files.include("README.rdoc", "lib/**/*.rb")
end

# Publishing ------------------------------------------------------

desc "Release to gemcutter"
task :release => :package do
  require 'rake/gemcutter'
  Rake::Gemcutter::Tasks.new(spec).define
  Rake::Task['gem:push'].invoke
end
