# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
