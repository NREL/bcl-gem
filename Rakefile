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
  # to call: rake "bcl:upload_content[true]" 
  # TODO: catch errors and continue
  desc 'upload/update BCL content'
  task :upload_content, [:reset] do |t, args|
    # process options
    options = {reset: false}
    if args[:reset].to_s == 'true'
      options[:reset] = true 
    end

    puts "OPTIONS -- reset: #{options[:reset]}"

    # initialize BCL and login
    bcl = BCL::ComponentMethods.new
    bcl.login

    total_count = 0;
    successes = 0;
    errors = 0;
    skipped = 0;

    staged_path = Pathname.new(Dir.pwd + '/staged')

    # grab all the new measure and component tar files and push to bcl
    ['measure', 'component'].each do |content_type|
      items = []
      paths = Pathname.glob(staged_path.to_s + "/push/#{content_type}/*.tar.gz")
      paths.each do |path|
        #puts path
        items << path.to_s
      end

      items.each do |item|
        puts item
        total_count += 1;

        receipt_file = File.dirname(item) + '/' + File.basename(item, '.tar.gz') + '.receipt'
        if !options[:reset] && File.exist?(receipt_file)
          skipped += 1;
          puts "SKIP: receipt file found"
          next
        end

        valid, res = bcl.push_content(item, true, "nrel_#{content_type}")
        if valid
          successes += 1;
        else
          errors += 1;
          puts "ERROR: #{res.inspect.chomp}"
        end
      end
    end

    # grab all the updated content (measures and components) tar files and push to bcl
    items = []
    paths = Pathname.glob(staged_path.to_s + '/update/*.tar.gz')
    paths.each do |path|
      #puts path
      items << path.to_s
    end
    items.each do |item|
      puts item
      total_count += 1;

      receipt_file = File.dirname(item) + '/' + File.basename(item, '.tar.gz') + '.receipt'
      if !options[:reset] && File.exist?(receipt_file)
        skipped += 1;
        puts "SKIP: receipt file found"
        next
      end

      valid, res = bcl.update_content(item, true)
      if valid
        successes += 1;
      else
        errors += 1;
        puts "ERROR: #{res.inspect.chomp}"
      end
    end

    puts "****DONE**** #{total_count} total, #{successes} success, #{errors} failures, #{skipped} skipped"

  end

  # to call: rake "bcl:stage_content[/path/to/your/content/directory, true]" 
  desc 'stage content for BCL'
  task :stage_content, [:content_path, :reset] do |t, args|
    # process options
    options = {reset: false}
    options[:content_path] = Pathname.new args[:content_path]
    if args[:reset].to_s == 'true'
      options[:reset] = true
    end
    puts "OPTIONS -- content_path: #{options[:content_path]}, reset: #{options[:reset]}"

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
    FileUtils.mkdir_p(staged_path.to_s + '/push/component')
    FileUtils.mkdir_p(staged_path.to_s + '/push/measure')

    # get all content directories to process
    dirs = Dir.glob("#{options[:content_path]}/*")

    dirs.each do |dir|
      next if dir.include?('Rakefile')
      current_d = Dir.pwd
      content_name = File.basename(dir)
      puts "Generating #{content_name}"

      Dir.chdir(dir)
      
      # figure out whether to upload new or update existing
      files = Pathname.glob('**/*')
      uuid = nil
      vid = nil
      content_type = 'measure'

      paths = []
      files.each do |file|
        paths << file.to_s
        if file.to_s =~ /^.{0,2}component.xml$/ || file.to_s =~ /^.{0,2}measure.xml$/
          if file.to_s =~ /^.{0,2}component.xml$/
            content_type = 'component'
          end
          # extract uuid  and vid
          uuid, vid = bcl.uuid_vid_from_xml(file)
          # TODO: what if this fails?  keep going and just skip this measure. add try/catch
        end
      end
      puts "UUID: #{uuid}, VID: #{vid}"

      # if uuid is missing, will assume new content
      # new content functionality needs to know if measure or component.  update is agnostic.
      action = bcl.search_by_uuid(uuid, vid)
      puts "#{content_name} ACTION TO TAKE: #{action}"

      if action == 'noop'  # ignore up-to-date content
        puts "*** WARNING: local #{content_name} uuid and vid match BCL...no update will be performed ***"
        next
      elsif action == 'update'
        #puts "#{content_name} labeled as update for BCL"
        destination = staged_path.join(action, "#{content_name}.tar.gz")
      elsif action == 'push'
        #puts "#{content_name} labeled as new content for BCL"
        destination = staged_path.join(action, content_type, "#{content_name}.tar.gz")
      end

      puts "destination: #{destination}"

      # copy over only if 'reset_receipts' is set to TRUE. otherwise ignore if file exists already
      if File.exist?(destination)
        if options[:reset]
          FileUtils.rm(destination)
          BCL.tarball(destination, paths)
        else
          puts "*** WARNING: File #{content_name}.tar.gz already exists in staged directory...keeping existing file. To overwrite, set reset_receipts arg to true ***"
        end
      else
        BCL.tarball(destination, paths)
      end
      Dir.chdir(current_d)
    end
  end

  # to call: rake "bcl:prep_and_push[/path/to/your/content/directory, true]"  
  # content_path arg: path to components or measures to upload
  # reset flag:  
    # If TRUE: content in the staged directory will be re-generated and receipt files will be deleted.  
    # If FALSE, content that already exists in the staged directory will remain and content with receipt files will not be re-uploaded.
  desc 'stage and push/update all content in a repo'
  task :stage_and_upload, [:content_path, :reset] do |t, args|
    options = {reset: false}
    options[:content_path] = Pathname.new args[:content_path]
    if args[:reset].to_s == 'true'
      options[:reset] = true
    end

    current_dir = Dir.pwd

    # stage content
    Rake.application.invoke_task("bcl:stage_content[#{options[:content_path]}, #{options[:reset]}]")
    Dir.chdir(current_dir)

    # upload (new and updated). pass in skip flag
    Rake.application.invoke_task("bcl:upload_content[#{options[:reset]}]")

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
