######################################################################
#  Copyright (c) 2008-2013, Alliance for Sustainable Energy.
#  All rights reserved.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by th e Free Software Foundation; either
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

# Provides programmatic access to the component.xsd schema needed for
# generating the component information that will be uploaded to
# the Building Component Library.

module BCL
  class Measure
    def initialize(save_path)
      super(save_path)

    end

    def read_measure_xml(filepath)
      xmlfile = File.open(filepath, 'r').read

      @xml = LibXML::XML::Document.string(xmlfile)
    end
  end
end
