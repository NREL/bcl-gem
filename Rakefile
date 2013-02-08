require 'rake/testtask'

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "bcl/version"

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/*.rb']
  t.verbose = true
end

task :release => :build do
  system "gem push bcl-#{BCL::VERSION}.gem"
  system "rm bcl-#{BCL::VERSION}.gem"
end

desc "Build gem"
task :build do
  system "gem build bcl.gemspec"
end

desc "import a new build of the taxonomy"
task :import_taxonomy do
  require 'rubygems'
  require 'bcl'
  require 'pathname'

  dirname = Pathname.new(__FILE__)

  taxonomy = BCL::MasterTaxonomy.new(dirname + '../../../Taxonomy/unified taxonomy.xlsm')
  taxonomy.save_as_current_taxonomy()
  taxonomy.save_as_current_taxonomy(dirname + 'lib/bcl/current_taxonomy.json')
  taxonomy.write_xml(dirname + 'lib/bcl/current_taxonomy.xml')
end

desc "install gem"
task :install => :build do
  system "gem install bcl-#{BCL::VERSION}.gem"
end

desc "uninstall all gems"
task :uninstall do
  system "gem uninstall bcl -a"
end

task :reinstall => [:uninstall, :install]

desc "Run tests"
task :default => :test