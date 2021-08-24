# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

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
