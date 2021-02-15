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

# KAF 2/13/2018
# This functionality is being kept in case we need in to recreate weather files in the future
# It is very out of date and would need a major reworking wrt to the updated schema

module BCL
  ProvStruct = Struct.new(:author, :datetime, :comment)
  TagsStruct = Struct.new(:descriptor)
  AttrStruct = Struct.new(:name, :value, :datatype, :units)
  FileStruct = Struct.new(:version_software_program, :version_id, :fqp_file, :filename, :filetype, :usage_type, :checksum)
  CostStruct = Struct.new(:cost_name, :cost_type, :category, :value, :interval,
                          :interval_units, :year, :location, :units, :currency, :source,
                          :reference_component_name, :reference_component_id)

  ObjectStruct = Struct.new(:obj_type, :obj_instance)

  class BaseXml
    attr_accessor :name
    attr_accessor :description
    attr_accessor :modeler_description
    attr_accessor :uuid
    attr_accessor :vuid

    attr_accessor :attributes
    attr_accessor :files
    attr_accessor :costs
    attr_accessor :tags
    attr_accessor :provenances

    def initialize(_save_path)
      @name = '' # this is also a unique identifier to the component...
      @description = ''
      @modeler_description = ''

      @provenances = []
      @tags = []
      @attributes = []
      @files = []

      @schema_url = 'schema.xsd'
    end

    def generate_uuid
      @uuid = UUID.new.generate
    end

    def generate_vuid
      @vuid = UUID.new.generate
    end

    def add_provenance(author, datetime, comment)
      prov = ProvStruct.new
      prov.author = author
      prov.datetime = datetime
      prov.comment = comment

      @provenances << prov
    end

    def add_tag(tag_name)
      tag = TagsStruct.new
      tag.descriptor = tag_name

      @tags << tag
    end

    def add_attribute(name, value, units, datatype = nil)
      attr = AttrStruct.new
      attr.name = name
      attr.value = value

      if !datatype.nil?
        attr.datatype = datatype
      else
        attr.datatype = get_datatype(value)
      end
      attr.units = units

      @attributes << attr
    end

    def add_file(version_sp, version_id, fqp_file, filename, filetype, usage_type = nil, checksum = nil)
      fs = FileStruct.new
      fs.version_software_program = version_sp
      fs.version_id = version_id
      fs.fqp_file = fqp_file
      fs.filename = filename
      fs.filetype = filetype
      fs.usage_type = usage_type unless usage_type.nil?
      fs.checksum = checksum unless checksum.nil?

      @files << fs
    end

    # return the title case of the string
    def tc(input)
      val = input.gsub(/\b\w/) { $&.upcase }
      if val.casecmp('energyplus').zero?
        val = 'EnergyPlus'
      end

      val
    end

    def get_attribute(attribute_name)
      result = nil
      @attributes.each do |attr|
        if attr.name == attribute_name
          result = attr
        end
      end

      result
    end

    def get_datatype(input_value)
      dt = 'undefined'

      # simple method to test if the input_value is a string, float, or integer.
      # First convert the value back to a string for testing (in case it was passed as a float/integer)
      test = input_value.to_s
      input_value = begin
                      test.match('\.').nil? ? Integer(test) : Float(test)
                    rescue StandardError
                      test.to_s
                    end

      if input_value.is_a?(Integer) || input_value.is_a?(Integer)
        dt = 'int'
      elsif input_value.is_a?(Float)
        dt = 'float'
      else
        dt = 'string'
      end

      dt
    end
  end
end
