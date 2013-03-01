$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require 'rspec'
require 'bcl'
require 'fileutils'
require 'yaml'

#any helper methods go here

config_file = File.dirname(__FILE__) + '/config.yml'
$config = nil
if File.exists?(config_file)
  puts "loading config settings from #{config_file}"
  $config = YAML.load_file(config_file)
else
  FileUtils.copy(config_file.to_s + ".template", config_file)
  puts "******** Please fill in user credentials in the rspec/config.yml file.  DO NOT COMMIT THIS FILE. **********"
  exit
end

