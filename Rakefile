require "bundler"    #don't use bundler right now because it runs these rake tasks differently
Bundler.setup

require "rake"
require "rspec/core/rake_task"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "bcl/version"

task :gem => :build
desc "build gem"
task :build do
  system "gem build bcl.gemspec"
end

desc "install gem from local build"
task :install => :build do
  system "gem install bcl-#{BCL::VERSION}.gem --no-ri --no-rdoc"
end

desc "build and release version of gem on rubygems.org"
task :release => :build do
  system "git tag -a v#{BCL::VERSION} -m 'Tagging #{BCL::VERSION}'"
  system "git push --tags"
  system "gem push bcl-#{BCL::VERSION}.gem"
  system "rm bcl-#{BCL::VERSION}.gem"
end

desc "import a new build of the taxonomy"
task :import_taxonomy do
  require 'rubygems'
  require 'bcl'
  require 'pathname'

  dirname = Pathname.new(File.dirname(__FILE__))
  path_to_taxonomy = File.join(dirname,"../../Taxonomy")
 
  puts dirname
  taxonomy = BCL::MasterTaxonomy.new("#{path_to_taxonomy}/unified taxonomy.xlsm")
  taxonomy.save_as_current_taxonomy
  taxonomy.save_as_current_taxonomy(dirname + 'lib/bcl/current_taxonomy.json')
  taxonomy.write_xml(dirname + 'lib/bcl/current_taxonomy.xml')
end


desc "uninstall all gems"
task :uninstall do
  system "gem uninstall bcl -a"
end

task :reinstall => [:uninstall, :install]

RSpec::Core::RakeTask.new("spec") do |spec|
  puts "running tests..."
  spec.pattern = "spec/**/*_spec.rb"
end

desc "Default task run rspec tests"
task :test => :spec
task :default => :spec

