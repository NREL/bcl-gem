require 'bundler'    # don't use bundler right now because it runs these rake tasks differently
Bundler.setup

require 'rake'
require 'rspec/core/rake_task'

require 'pathname'

$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'bcl'
require 'bcl/version'

task gem: :build
desc 'build gem'
task :build do
  system 'gem build bcl.gemspec'
end

desc 'install gem from local build'
task install: :build do
  system "gem install bcl-#{BCL::VERSION}.gem --no-ri --no-rdoc"
end

desc 'build and release version of gem on rubygems.org'
task release: :build do
  system "git tag -a v#{BCL::VERSION} -m 'Tagging #{BCL::VERSION}'"
  system 'git push --tags'
  system "gem push bcl-#{BCL::VERSION}.gem"
  system "rm bcl-#{BCL::VERSION}.gem"
end

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
  filename = "#{File.dirname(__FILE__)}/spec/api/resources/measure_original.tar.gz"
  valid, res = bcl.push_content(filename, false, 'nrel_measure')
end

namespace :bcl do
  # to call: rake "bcl:upload_content[/path/to/your/content/directory, true]" 
  # TODO: catch errors and continue
  desc 'upload/update BCL content'
  task :upload_content, [:content_path, :reset_receipts] do |t, args|
    # process options
    options = {reset: false}
    options[:content_path] = Pathname.new args[:content_path]
    if args[:reset_receipts]
      options[:reset] = args[:reset_receipts]  
    end
    puts "OPTIONS: #{options[:content_path]}, #{options[:reset]}"

    # initialize BCL and login
    bcl = BCL::ComponentMethods.new
    bcl.login

    total_count = 0;
    successes = 0;
    errors = 0;
    skipped = 0;

    # TODO: handle skipping files

    staged_path = Pathname.new(Dir.pwd + '/staged')
    puts "STAGED PATH: #{staged_path}"
    # grab all the new content tar files and push to bcl
    measures = []
    paths = Pathname.glob(staged_path.to_s + '/push/*.tar.gz')
    puts "PATHS: #{paths}"
    paths.each do |path|
      puts path
      measures << path.to_s
    end
    measures.each do |item|
      puts item
      total_count += 1;
      # TODO:  differentiate btw measures and components (only matters for new content, not updates)
      valid, res = bcl.push_content(item, options[:reset], 'nrel_measure')
      if valid
        successes += 1;
      else
        errors += 1;
        puts "ERROR: #{res.inspect.chomp}"
      end
    end

    # grab all the updated content tar files and push to bcl
    measures = []

    paths = Pathname.glob(staged_path.to_s + '/update/*.tar.gz')
    puts "PATHS: #{paths}"
    paths.each do |path|
      puts path
      measures << path.to_s
    end
    measures.each do |item|
      puts item
      total_count += 1;
      # TODO:  differentiate btw measures and components
      valid, res = bcl.update_content(item, options[:reset])
      if valid
        successes += 1;
      else
        errors += 1;
        puts "ERROR: #{res.inspect.chomp}"
      end
    end

    puts "****DONE**** #{total_count} total, #{successes} success, #{errors} failures"

  end

  # to call: rake "bcl:generate_content[/path/to/your/content/directory, true]" 
  desc 'prepare content for BCL'
  task :generate_content, [:content_path, :reset_receipts] do |t, args|
    # process options
    options = {reset: false}
    options[:content_path] = Pathname.new args[:content_path]
    if args[:reset_receipts]
      options[:reset] = args[:reset_receipts]  
    end
    puts "OPTIONS: #{options[:content_path]}, #{options[:reset]}"

    # initialize BCL and login
    bcl = BCL::ComponentMethods.new
    bcl.login

    # verify staged directory exists
    staged_path = Pathname.new(Dir.pwd + '/staged')
    FileUtils.mkdir_p(staged_path)

    # delete existing tarballs if reset is true
    if options[:reset]
      FileUtils.rm_rf(Dir.glob("#{staged_path}/*"))
    end

    # create new and existing directories
    FileUtils.mkdir_p(staged_path.to_s + '/update')
    FileUtils.mkdir_p(staged_path.to_s + '/push')

    # get all content directories to process
    dirs = Dir.glob("#{options[:content_path]}/*")
    puts dirs.inspect

    dirs.each do |dir|
      next if dir.include?('Rakefile')
      current_d = Dir.pwd
      content_name = File.basename(dir)
      puts "Generating #{content_name}"

      Dir.chdir(dir)
      
      # figure out whether to upload new or update existing
      files = Pathname.glob('**/*')
      # files.each do |f|
      #   puts "  #{f}"
      # end
      uuid = nil
      vid = nil

      paths = []
      files.each do |file|
        paths << file.to_s
        if file.to_s =~ /^.{0,2}component.xml$/ || file.to_s =~ /^.{0,2}measure.xml$/
          # extract uuid  and vid
          uuid, vid = bcl.uuid_vid_from_xml(file)
          # TODO: what if this fails?  keep going and just skip this measure. add try/catch
        end
      end
      puts "UUID: #{uuid}, VID: #{vid}"

      action = bcl.search_by_uuid(uuid, vid)
      puts "#{content_name} ACTION TO TAKE: #{action}"

      if action == 'noop'  # ignore up-to-date content
        puts "local #{content_name} uuid and vid match BCL...no update will be performed"
        next
      elsif action == 'update'
        puts "#{content_name} labeled as update for BCL"
      elsif action == 'new'
        puts "#{content_name} labeled as new content for BCL"
      end

      # use absolute path
      destination = staged_path.join(action, "#{content_name}.tar.gz")
      FileUtils.rm(destination) if File.exist?(destination)
      BCL.tarball(destination, paths)
      Dir.chdir(current_d)
    end
  end

  # to call: rake "bcl:prep_and_push[/path/to/your/content/directory, true]"  
  desc 'prepare and push/update all content in a repo'
  task :prep_and_push, [:content_path, :reset_receipts] do |t, args|
    options = {reset: false}
    options[:content_path] = Pathname.new args[:content_path]
    if args[:reset_receipts]
      options[:reset] = args[:reset_receipts]  
    end

    current_dir = Dir.pwd

    Rake.application.invoke_task("bcl:generate_content[#{options[:content_path]}, #{options[:reset]}]")
    Dir.chdir(current_dir)

    # upload and update. pass in skip flag
    Rake.application.invoke_task("bcl:upload_content[#{options[:content_path]}, #{options[:reset]}]")

  end
end

task reinstall: [:uninstall, :install]

RSpec::Core::RakeTask.new('spec') do |spec|
  puts 'running tests...'
  spec.rspec_opts = %w(--format progress)
  spec.pattern = 'spec/**/*_spec.rb'
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
