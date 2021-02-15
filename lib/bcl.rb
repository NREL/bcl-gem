######################################################################
#  Copyright (c) 2008-2021, Alliance for Sustainable Energy.
#  All rights reserved.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
######################################################################

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
