require 'pathname'
require 'base64'

begin
  require 'openstudio'
  $openstudio_gem = true
rescue LoadError => e
  $openstudio_gem = false
  puts 'OpenStudio did not load, but most functionality is still available. Will continue...'
end

# file formatters
require 'yaml'
require 'multi_json'
require 'libxml'
require 'builder'

# todo: can we condense these into one?
require 'archive/tar/minitar'
require 'zlib'
require 'zip'

require 'rubyXL'

require 'bcl/bcl_xml'
require 'bcl/component_spreadsheet'
require 'bcl/component_from_spreadsheet'
require 'bcl/component_xml'
require 'bcl/component_methods'
require 'bcl/measure_xml'
require 'bcl/tar_ball'
require 'bcl/master_taxonomy'
require 'bcl/version'

