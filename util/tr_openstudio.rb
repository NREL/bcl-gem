#!/usr/bin/ruby

# Simple OSMeasure Test Runner
# 2016.10.06 RPG/NREL
# TODO add a scanner(s) for Rspec et al. test defs

require 'optparse'
require 'csv'
require 'json'

# options parser

options = {}

optparse = OptionParser.new do|opts|

  opts.banner = "\nUsage: #{$0} [options]\n\nScans all specified test files for (Minitest) tests and \
  \nruns them; errors reported to file."
   
  opts.separator ""
  opts.separator "Options:"
  
  options[:wd] = Dir.pwd
  opts.on( '-d', '--directory <value>', "Working directory (default: '.')") do|f|
    options[:wd] = f
  end
  
  options[:test_file] = nil
  opts.on( '-t', '--test <file1,file2...>', "Test filename(s)" ) do|f|
    options[:test_file] = f.split(",")
  end

  options[:tests_map] = nil
  opts.on( '-m', '--mask <regex>', "Regex search for test file(s)" ) do|f|
    options[:tests_map] = f
  end

  options[:envs] = ["lib"]
  opts.on( '-e', '--env <path1,path2,...>', "Ruby environment path(s) (default: 'lib')" ) do|f|
    options[:envs] = f.split(",")
  end
  
  opts.on( '-f', '--fetch', "Fetch measures from BCL and exit" ) do|f|
    options[:bcl_fetch] = f
  end

  options[:bcl_query] = 'NREL'
  opts.on( '-b', '--bcl <query>', "BCL measure query (default: 'NREL')" ) do|f|
    options[:bcl_query] = f
  end

  options[:test_bcl] = false
  opts.on( '-a', '--auto', "Test NREL BCL measures" ) do|f|
    options[:test_bcl] = f
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end

end.parse!


# Fetch measures from BCL
if options[:bcl_fetch] || options[:test_bcl]
	puts "INFO: Fetching measures tagged '#{options[:bcl_query]}' from BCL..."
	require 'bcl'
	require 'bcl/version'
	bcl = BCL::ComponentMethods.new
	bcl.login   # sets the BCL URL
	bcl.measure_metadata(options[:bcl_query])
  puts 'BCL fetch complete.'
	exit if options[:bcl_fetch]
end

tests = []
measures = []
if options[:test_bcl]
  measures = Dir.glob("measures/parsed/**")
  tests = Dir.glob("measures/parsed/**/tests/*_[tT]est.rb")

elsif !options[:test_file] && !options[:tests_map]
	puts "#{$0}: ERROR: No test(s) specified, use '-t --test', '-m --mask', or try '#{$0} -h' for help."
	exit

# TODO support both filespecs
elsif 
  options[:test_file] && !options[:tests_map]
	tests = Dir.glob(options[:test_file])

elsif 
  options[:tests_map] && !options[:test_file]
  tests = Dir.glob(options[:tests_map])

elsif 
  options[:tests_map] && options[:test_file]
  puts "#{$0}: Specify file name(s) or a search mask/regex, not both."
  exit

end


puts "#{$0}: Working directory = #{options[:wd]}"

if tests.size == 0 
	puts "#{$0}: No files matched spec; check test file list/mask or try '#{$0} -h' for help."
	exit
end
puts "#{$0}: Running #{tests.size} test file(s)"

log = []
errors = []
log_json = []

# scan test files for test definitions
query = "def +test_([A-Za-z_0-9]+)" # minitest
#query_spec = "it +([A-Za-z_0-9]+)" # RSpec (in progress)

envs = options[:envs]


# store the binding before each measure
b = binding
measures.each do |measure|
  require 'openstudio'
  
  bcl_measure = OpenStudio::BCLMeasure.load(measure)
  
  if bcl_measure.empty?
    puts "Cannot load measure '#{measure}'"
  else
    bcl_measure = bcl_measure.get
    
    # see if there are updates, want to make sure to perform both checks so do outside of conditional
    file_updates = bcl_measure.checkForUpdatesFiles # checks if any files have been updated
    xml_updates = bcl_measure.checkForUpdatesXML # only checks if xml as loaded has been changed since last save
    
    missing_fields = false
    begin
      missing_fields = bcl_measure.missingRequiredFields
    rescue
    end
      
    if file_updates || xml_updates || missing_fields
      puts "Changes detected in measure'#{measure}'"

      # try to load the ruby measure
      info = nil
      begin
        info = eval("OpenStudio::Ruleset.getInfo(bcl_measure, OpenStudio::Model::OptionalModel.new, OpenStudio::OptionalWorkspace.new)", b)
      rescue Exception => e  
        info = OpenStudio::Ruleset::RubyUserScriptInfo.new(e.message)
      end
      info.update(bcl_measure)

      # do the save
      #bcl_measure.save
    end
  end
end


tests.each do |test|
	puts "#{$0}: Scanning file #{test} for tests..."
	test_scan = File.readlines(test)
	matches = test_scan.select { |name| name[/#{query}/] }
  # TEST FILE
  log_testfile = []
	matches.each do |cmd|
    # TEST NAME hash
    testname_hash = {}
    test_name = "#{cmd.split(" ")[1]}"
    log_env = []
		envs.each do |env|
      test_path = File.join(options[:wd], test)
			test_cmd = "ruby -I#{env} \"#{test_path}\" --name=#{test_name}"
			puts "#{$0} running '#{test_cmd}'"
			system(test_cmd)
 			log << ["#{env}","#{test}","#{test_name}","#{$?.exitstatus}"]
      # ENV and status code
      env_hash = {}
      env_hash['env'] = env
      env_hash['exit_status'] = $?.exitstatus
      log_env << env_hash
			if $?.exitstatus !=0
        errors << ["#{test_name}","#{test}","#{env}","#{$?.exitstatus}"]
      end
		end
    testname_hash['name'] = test_name
    testname_hash['results'] = log_env
    log_testfile << testname_hash
	end
  testfile_hash = {}
  testfile_hash['name'] = test
  testfile_hash['tests'] = log_testfile
  log_json << testfile_hash
end

log_file = 'test_log.csv'
CSV.open("#{log_file}", 'w') do |report|
	report << ["ENV_STRING","TEST_SOURCE","TEST_NAME","EXIT_CODE"]
	log.each do |row|
		report << row
	end
end

File.open('test_log.json', 'w') { |f| f << JSON.pretty_generate(log_json)}

puts "#{$0}: Tests complete. Test runner ran #{log.size} total tests, with #{errors.size} errors."
puts "#{$0}: See #{options[:wd]}/#{log_file} or test_log.csv for details." if errors.size > 0
