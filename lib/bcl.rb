# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

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
require 'json'
require 'builder'
require 'uuid'
require 'net/https'
require 'rexml/document'

# TODO: can we condense these into one?
require 'minitar'
require 'zlib'
require 'zip'

# ability to write spreadsheets
require 'spreadsheet'

require 'bcl/core_ext'
require 'bcl/base_xml'
require 'bcl/component_from_spreadsheet'
require 'bcl/component'
require 'bcl/component_methods'
require 'bcl/tar_ball'
require 'bcl/version'

# Some global structures

WorksheetStruct = Struct.new(:name, :components)
HeaderStruct = Struct.new(:name, :children)
ComponentStruct = Struct.new(:row, :name, :uid, :version_id, :headers, :values)
