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

  opts.banner = "\nUsage: #{$0} [options]\n\nScans all specified measure directories for (Minitest) tests and \
  \nruns them; errors reported to file."
   
  opts.separator ""
  opts.separator "Options:"
  
  options[:wd] = Dir.pwd
  opts.on( '-d', '--directory <value>', "Working directory (default: '.')") do|f|
    options[:wd] = f
  end

  options[:measures] = nil
  opts.on( '-m', '--measure <dir1,dir2>, <measures/**>', "Measure name(s) to test" ) do|f|
    options[:measures] = f
  end

  options[:tests_dir] = "tests"
  opts.on( '-t', '--testdir <directory>', "Measure test director(ies) (default: '<measure_dir>/tests')" ) do|f|
    options[:tests_dir] = f
  end  

  options[:testfile_mask] = "*_[tT]est.rb"
  opts.on( '-x', '--testspec <regex>', "Search spec for test file(s) (default: '*_[tT]est.rb')" ) do|f|
    options[:testfile_mask] = f
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


measures = []
test_files = []

if options[:test_bcl]
  measures = Dir.glob("measures/parsed/**")
  test_files = Dir.glob("measures/parsed/**/tests/*_[tT]est.rb")

else
  measures = Dir.glob(options[:measures].split(/[\s,]/)).select { |fn| File.directory?(fn) }
  test_dir = options[:tests_dir]
  testfile_mask = options[:testfile_mask]
  puts "Inspecting #{measures.size} measure directories..."
  measures.each do |m|
    tfile_search = File.join(m, test_dir, "*.rb")
    t_tf = Dir.glob(tfile_search)      
    test_files << t_tf
  end
  puts "Found #{test_files.size} test files:"
  puts test_files

end  

puts "#{$0}: Working directory = #{options[:wd]}"

if test_files.size == 0 
	puts "#{$0}: No measures matched spec; check measure list/mask or try '#{$0} -h' for help."
	exit
end
puts "#{$0}: Running #{test_files.size} test file(s)"

test_files = [] # we'll build this again in a sec...

log = []
errors = []
log_json = []

# scan test files for test Minitest definitions
query = "def +test_([A-Za-z_0-9]+)"


envs = options[:envs]

## integrity check
# store the binding before each measure
def bcl_ok(measure)

  changes = false
  
  b = binding
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
      changes = true
      puts "Changes detected in measure '#{measure}'"

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

  return true if !changes

end


measures.each do |m|
  measure_clean = "#{m.split("[/\\]")[-1]}" # works on Windows?
  puts "Testing measure: '#{measure_clean}'"

  bcl_status = "OK"
  if !bcl_ok(m)
    bcl_status = "changed"
  end
  log_json << measure_clean
  log_json << bcl_status
  test_files = []
  tfile_search = File.join(m, test_dir, "*.rb")
  t_tf = Dir.glob(tfile_search)      
  test_files << t_tf
  test_files.each do |test|
    puts test
  	puts "#{$0}: Scanning file #{test} for tests..."
  	test_scan = File.readlines(test[0])
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
   			log << ["#{measure_clean}","#{bcl_status}","#{env}","#{test}","#{test_name}","#{$?.exitstatus}"]
        # ENV and status code
        env_hash = {}
        env_hash['Ruby lib'] = env
        env_hash['exit_status'] = $?.exitstatus
        log_env << env_hash
  			if $?.exitstatus !=0
          errors << ["#{test_name}","#{test}","#{env}","#{$?.exitstatus}"]
        end
  		end
      testname_hash['test_name'] = test_name
      testname_hash['details'] = log_env
      log_testfile << testname_hash
  	end
    testfile_hash = {}
    testfile_hash['test_file'] = test
    testfile_hash['tests'] = log_testfile
    log_json << testfile_hash
  end

end

log_file = 'test_log.csv'
CSV.open("#{log_file}", 'w') do |report|
	report << ["MEASURE_NAME","ENV_STRING","TEST_SOURCE","TEST_NAME","EXIT_CODE"]
	log.each do |row|
		report << row
	end
end

File.open('test_log.json', 'w') { |f| f << JSON.pretty_generate(log_json)}

puts "Test runner complete:\nMeasures:\t#{measures.count}\nTests:\t\t#{log.size}\nErrors:\t\t#{errors.size}"
