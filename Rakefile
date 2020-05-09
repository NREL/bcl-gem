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
    bcl.login
    results = bcl.search('Add', 'show_rows=10', false)
    puts "there are #{results[:result].count} results"
    results[:result].each do |res|
      puts (res[:measure][:name]).to_s
    end
  end

  desc 'test measure upload'
  task :measure_upload do
    bcl = BCL::ComponentMethods.new
    bcl.login
    filename = "#{File.dirname(__FILE__)}/spec/api/resources/measure_original.tar.gz"
    valid, res = bcl.push_content(filename, false, 'nrel_measure')
  end

  desc 'test the BCL login credentials defined in .bcl/config.yml'
  task :bcl_login do
    bcl = BCL::ComponentMethods.new
    bcl.login
  end

  desc 'test component spreadsheet'
  task :spreadsheet do
    bclcomponents = BCL::ComponentFromSpreadsheet.new(File.expand_path('lib/files/Components.xls', __dir__), ['Roofing'])
    bclcomponents.save(File.expand_path('lib/files/staged', __dir__))
  end

  desc 'test measure download'
  task :measure_download do
    # find a component with keyword 'Ashrae'
    query = 'ashrae'
    filter = 'fq[]=bundle:nrel_component&show_rows=3'

    bcl = BCL::ComponentMethods.new
    bcl.login

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
end

namespace :bcl do
  STAGED_PATH = Pathname.new(Dir.pwd + '/staged')

  # initialize BCL and login
  bcl = BCL::ComponentMethods.new
  bcl.login

  # to call: rake "bcl:stage_and_upload[/path/to/your/content/directory, true]"
  # content_path arg: path to components or measures to upload
  # reset flag:
  # If TRUE: content in the staged directory will be re-generated and receipt files will be deleted.
  # If FALSE, content that already exists in the staged directory will remain and content with receipt files will not be re-uploaded.
  desc 'stage and push/update all content in a repo'
  task :stage_and_upload, [:content_path, :reset] do |t, args|
    options = { reset: false }
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

  # to call: rake "bcl:upload_content[true]"
  # TODO: catch errors and continue
  desc 'upload/update BCL content'
  task :upload_content, [:reset] do |t, args|
    # process options
    options = { reset: false }
    if args[:reset].to_s == 'true'
      options[:reset] = true
    end

    total_count = 0
    successes = 0
    errors = 0
    skipped = 0

    # grab all the new measure and component tar files and push to bcl
    ['measure', 'component'].each do |content_type|
      items = []
      paths = Pathname.glob(STAGED_PATH.to_s + "/push/#{content_type}/*.tar.gz")
      paths.each do |path|
        # puts path
        items << path.to_s
      end

      items.each do |item|
        puts item.split('/').last
        total_count += 1

        receipt_file = File.dirname(item) + '/' + File.basename(item, '.tar.gz') + '.receipt'
        if !options[:reset] && File.exist?(receipt_file)
          skipped += 1
          puts 'SKIP: receipt file found'
          next
        end

        valid, res = bcl.push_content(item, true, "nrel_#{content_type}")
        if valid
          successes += 1
        else
          errors += 1
          if res.key?(:error)
            puts "  ERROR MESSAGE: #{res[:error]}"
          else
            puts "ERROR: #{res.inspect.chomp}"
          end
        end
        puts '', '---'
      end
    end

    # grab all the updated content (measures and components) tar files and push to bcl
    items = []
    paths = Pathname.glob(STAGED_PATH.to_s + '/update/*.tar.gz')
    paths.each do |path|
      # puts path
      items << path.to_s
    end
    items.each do |item|
      puts item.split('/').last
      total_count += 1

      receipt_file = File.dirname(item) + '/' + File.basename(item, '.tar.gz') + '.receipt'
      if !options[:reset] && File.exist?(receipt_file)
        skipped += 1
        puts 'SKIP: receipt file found'
        next
      end

      valid, res = bcl.update_content(item, true)
      if valid
        successes += 1
      else
        errors += 1
        if res.key?(:error)
          puts "  ERROR MESSAGE: #{res[:error]}"
        else
          puts "ERROR MESSAGE: #{res.inspect.chomp}"
        end
      end
      puts '', '---'
    end

    puts "****UPLOAD DONE**** #{total_count} total, #{successes} success, #{errors} failures, #{skipped} skipped"
  end

  # to call: rake "bcl:stage_content[/path/to/your/content/directory, true]"
  desc 'stage content for BCL'
  task :stage_content, [:content_path, :reset] do |t, args|
    # process options
    options = { reset: false }
    options[:content_path] = Pathname.new args[:content_path]
    if args[:reset].to_s == 'true'
      options[:reset] = true
    end
    puts "OPTIONS -- content_path: #{options[:content_path]}, reset: #{options[:reset]}"

    FileUtils.mkdir_p(STAGED_PATH)

    # delete existing tarballs if reset is true
    if options[:reset]
      FileUtils.rm_rf(Dir.glob("#{STAGED_PATH}/*"))
    end

    # create new and existing directories
    FileUtils.mkdir_p(STAGED_PATH.to_s + '/update')
    FileUtils.mkdir_p(STAGED_PATH.to_s + '/push/component')
    FileUtils.mkdir_p(STAGED_PATH.to_s + '/push/measure')

    # keep track of noop, update, push
    noops = 0
    new_ones = 0
    updates = 0

    # get all content directories to process
    dirs = Dir.glob("#{options[:content_path]}/*")

    dirs.each do |dir|
      next if dir.include?('Rakefile')

      current_d = Dir.pwd
      content_name = File.basename(dir)
      puts '', '---'
      puts "Generating #{content_name}"

      Dir.chdir(dir)

      # figure out whether to upload new or update existing
      files = Pathname.glob('**/*')
      uuid = nil
      vid = nil
      content_type = 'measure'

      paths = []
      files.each do |file|
        # don't tar tests/outputs directory
        next if file.to_s.start_with?('tests/output') # From measure testing process
        next if file.to_s.start_with?('tests/test') # From openstudio-measure-tester-gem
        next if file.to_s.start_with?('tests/coverage') # From openstudio-measure-tester-gem
        next if file.to_s.start_with?('test_results') # From openstudio-measure-tester-gem

        paths << file.to_s
        if file.to_s =~ /^.{0,2}component.xml$/ || file.to_s =~ /^.{0,2}measure.xml$/
          if file.to_s.match?(/^.{0,2}component.xml$/)
            content_type = 'component'
          end
          # extract uuid  and vid
          uuid, vid = bcl.uuid_vid_from_xml(file)
        end
      end
      puts "UUID: #{uuid}, VID: #{vid}"

      # note: if uuid is missing, will assume new content
      action = bcl.search_by_uuid(uuid, vid)
      puts "#{content_name} ACTION TO TAKE: #{action}"
      # new content functionality needs to know if measure or component.  update is agnostic.
      if action == 'noop' # ignore up-to-date content
        puts "  - WARNING: local #{content_name} uuid and vid match BCL... no update will be performed"
        noops += 1
        next
      elsif action == 'update'
        # puts "#{content_name} labeled as update for BCL"
        destination = STAGED_PATH.join(action, "#{content_name}.tar.gz")
        updates += 1
      elsif action == 'push'
        # puts "#{content_name} labeled as new content for BCL"
        destination = STAGED_PATH.join(action, content_type, "#{content_name}.tar.gz")
        new_ones += 1
      end

      puts "destination: #{destination}"

      # copy over only if 'reset_receipts' is set to TRUE. otherwise ignore if file exists already
      if File.exist?(destination)
        if options[:reset]
          FileUtils.rm(destination)
          BCL.tarball(destination, paths)
        else
          puts "*** WARNING: File #{content_name}.tar.gz already exists in staged directory... keeping existing file. To overwrite, set reset_receipts arg to true ***"
        end
      else
        BCL.tarball(destination, paths)
      end
      Dir.chdir(current_d)
    end
    puts '', "****STAGING DONE**** #{new_ones} new content, #{updates} updates, #{noops} skipped (already up-to-date on BCL)", ''
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
