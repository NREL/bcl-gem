require 'bundler'    # don't use bundler right now because it runs these rake tasks differently
Bundler.setup
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'bcl'
require 'bcl/version'

require 'rspec/core/rake_task'

# Always create spec reports
require 'ci/reporter/rake/rspec'

desc 'import a new build of the taxonomy'
task :import_taxonomy do
  require 'pathname'

  dirname = Pathname.new(File.dirname(__FILE__))
  puts dirname
  path_to_taxonomy = File.join(dirname, '../Utilities/Taxonomy')
  path_to_taxonomy = 'C:/Projects/Utilities/Taxonomy'

  puts dirname
  taxonomy = BCL::MasterTaxonomy.new("#{path_to_taxonomy}/unified taxonomy.xlsm")
  taxonomy.save_as_current_taxonomy
  taxonomy.save_as_current_taxonomy(dirname + 'lib/bcl/current_taxonomy.json')
  taxonomy.write_xml(dirname + 'lib/bcl/current_taxonomy.xml')
end

desc 'uninstall all gems'
task :uninstall do
  system 'gem uninstall bcl -a'
end

desc 'retrieve measures, parse, and create json metadata file'
task :measure_metadata do
  bcl =  BCL::ComponentMethods.new
  bcl.login   # do this to set BCL URL
  # only retrieve "NREL" measures
  bcl.measure_metadata('NREL')
end

desc 'test search all functionality'
task :search_all do
  # search with all=true
  # ensure that a) results are returned (> 0) and b) [:measure][:name] is a string
  # search with all=false
  # ensure the same a) and b) as above
  bcl = BCL::ComponentMethods.new
  bcl.login
  results = bcl.search('Add', 'show_rows=10', false)
  puts "there are #{results[:result].count} results"
  results[:result].each do |res|
    puts "#{res[:measure][:name]}"
  end
end

desc 'test measure upload'
task :measure_upload do
  bcl = BCL::ComponentMethods.new
  bcl.login
  filename = "#{File.dirname(__FILE__)}/spec/api/resources/measure_example.tar.gz"
  valid, res = bcl.push_content(filename, true, 'nrel_measure')
end

task reinstall: [:uninstall, :install]

RSpec::Core::RakeTask.new('spec') do |spec|
  puts 'running tests...'
  spec.rspec_opts = %w(--format progress)
  spec.pattern = 'spec/**/*_spec.rb'
end

task 'spec' => 'ci:setup:rspec'

task default: 'spec'

require 'rubocop/rake_task'
desc 'Run RuboCop on the lib directory'
RuboCop::RakeTask.new(:rubocop) do |task|
  # only show the files with failures
  task.options = ['--no-color', '--out=rubocop-results.xml']
  task.formatters = ['RuboCop::Formatter::CheckstyleFormatter']
  task.requires = ['rubocop/formatter/checkstyle_formatter']
  # don't abort rake on failure
  task.fail_on_error = false
end

