# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'bundler'
Bundler.setup

require 'rake'
require 'rspec/core/rake_task'
require 'bundler/gem_tasks'

require 'pathname'

$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'bcl'
require 'bcl/version'

RSpec::Core::RakeTask.new('spec') do |spec|
  puts 'running tests...'
  spec.rspec_opts = ['--format', 'progress']
  spec.pattern = 'spec/**/*_spec.rb'
end

namespace :test do
  desc 'test search all functionality'
  task :search_all do
    # search with all=true
    # ensure that a) results are returned (> 0) and b) [:measure][:name] is a string
    # search with all=false
    # ensure the same a) and b) as above
    bcl = BCL::ComponentMethods.new
    results = bcl.search('Add', 'show_rows=10', false)
    puts "there are #{results[:result].count} results returned in this response"
    puts "there are #{results[:complete_results_count]} total results available for this query"
    results[:result].each do |res|
      puts (res[:measure][:name]).to_s
    end
  end

  desc 'test search and return ALL versions functionality'
  task :search_all_versions do
    # search with all=true
    # ensure that a) results are returned (> 0) and b) [:measure][:name] is a string
    # search with all=false
    # ensure the same a) and b) as above
    bcl = BCL::ComponentMethods.new
    results = bcl.search('Add', 'show_rows=10&all_content_versions=1', false)
    puts "there are #{results[:result].count} results returned in this response"
    puts "there are #{results[:complete_results_count]} total results available for this query"
    results[:result].each do |res|
      puts (res[:measure][:name]).to_s
    end
  end

  desc 'test measure download'
  task :measure_download do
    # find a component with keyword 'Ashrae'
    query = 'ashrae'
    filter = 'fq=bundle:nrel_component&show_rows=3'

    bcl = BCL::ComponentMethods.new
    results = bcl.search(query, filter)
    uids = []
    results[:result].each do |result|
      uids << result[:component][:uuid]
    end

    content = bcl.download_component(uids[0])

    # save as tar.gz
    download_path = File.expand_path('lib/files/downloads', __dir__)
    FileUtils.mkdir(download_path) if !File.exist? download_path
    f = File.open("#{download_path}/#{uids[0]}.tar.gz", 'wb')
    f.write(content)
  end

  desc 'test measure download - legacy syntax'
  task :measure_download do
    # find a component with keyword 'Ashrae'
    query = 'ashrae'
    filter = 'fq[]=bundle:nrel_component&show_rows=3'

    bcl = BCL::ComponentMethods.new
    results = bcl.search(query, filter)
    uids = []
    results[:result].each do |result|
      uids << result[:component][:uuid]
    end

    content = bcl.download_component(uids[0])

    # save as tar.gz
    download_path = File.expand_path('lib/files/downloads', __dir__)
    FileUtils.mkdir(download_path) if !File.exist? download_path
    f = File.open("#{download_path}/#{uids[0]}.tar.gz", 'wb')
    f.write(content)
  end

  desc 'test component spreadsheet'
  task :spreadsheet do
    bclcomponents = BCL::ComponentFromSpreadsheet.new(File.expand_path('lib/files/Components.xls', __dir__), ['Roofing'])
    bclcomponents.save(File.expand_path('lib/files/staged', __dir__))
  end
end

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

desc 'Default task run rspec tests'
task test: :spec
task default: :spec
