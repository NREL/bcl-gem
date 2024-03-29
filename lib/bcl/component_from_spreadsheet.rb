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

# Converts a custom Excel spreadsheet format to BCL components for upload

require 'spreadsheet'
require 'bcl'

module BCL
  WorksheetStruct = Struct.new(:name, :components)
  HeaderStruct = Struct.new(:name, :children)
  ComponentStruct = Struct.new(:row, :name, :uid, :version_id, :headers, :values)

  class ComponentFromSpreadsheet
    @@changed = false

    # initialize with Excel spreadsheet to read
    # seems to only be working with xls spreadsheets
    def initialize(xlsx_path, worksheet_names = ['all'])
      @xlsx_path = Pathname.new(xlsx_path).realpath.to_s
      @worksheets = []

      begin
        xlsx = Spreadsheet.open(@xlsx_path)

        # by default, operate on all worksheets
        if worksheet_names == ['all']
          xlsx.worksheets.each do |xlsx_worksheet|
            parse_xlsx_worksheet(xlsx_worksheet)
          end
        else # if specific worksheets are specified, operate on them
          worksheet_names.each do |worksheet_name|
            parse_xlsx_worksheet(xlsx.worksheet(worksheet_name))
          end
        end

        # save spreadsheet if changes have been made
        if @@changed
          xlsx.write(@xlsx_path)
          puts '[ComponentFromSpreadsheet] Spreadsheet changes saved'
        end
      ensure
        xlsx = nil
      end
    end

    def save(save_path, chunk_size = 1000, delete_old_gather = false)
      # FileUtils.rm_rf(save_path) if File.exists?(save_path) and File.directory?(save_path)
      # TODO: validate against taxonomy

      @worksheets.each do |worksheet|
        worksheet.components.each do |component|
          component_xml = Component.new("#{save_path}/components")
          component_xml.name = component.name
          component_xml.uid = component.uid

          # this tag is how we know where this goes in the taxonomy
          component_xml.add_tag(worksheet.name)
          puts "tag: #{worksheet.name}"

          values = component.values

          puts " headers: #{component.headers}"
          component.headers.each do |header|
            if /description/i.match?(header.name)
              name = values.delete_at(0) # name, uid already processed
              uid = values.delete_at(0)
              component_xml.comp_version_id = values.delete_at(0)
              description = values.delete_at(0)
              component_xml.modeler_description = values.delete_at(0)
              component_xml.description = description
            elsif /provenance/i.match?(header.name)
              author = values.delete_at(0)
              datetime = values.delete_at(0)
              if datetime.nil?
                # puts "[ComponentSpreadsheet] WARNING missing the date in the datetime column in the spreadsheet - assuming today"
                datetime = DateTime.new
              end

              comment = values.delete_at(0)
              component_xml.add_provenance(author.to_s, datetime.strftime('%Y-%m-%d'), comment.to_s)
            elsif /tag/i.match?(header.name)
              value = values.delete_at(0)
              component_xml.add_tag(value)
            elsif /attribute/i.match?(header.name)
              value = values.delete_at(0)
              name = header.children[0]
              units = ''
              if match_data = /(.*)\((.*)\)/.match(name)
                name = match_data[1].strip
                units = match_data[2].strip
              end
              component_xml.add_attribute(name, value, units)
            elsif /source/i.match?(header.name)
              manufacturer = values.delete_at(0)
              model = values.delete_at(0)
              serial_no = values.delete_at(0)
              year = values.delete_at(0)
              url = values.delete_at(0)
              component_xml.source_manufacturer = manufacturer
              component_xml.source_model = model
              component_xml.source_serial_no = serial_no
              component_xml.source_year = year
              component_xml.source_url = url
            elsif /file/i.match?(header.name)
              software_program = values.delete_at(0)
              version = values.delete_at(0)
              filename = values.delete_at(0)
              filetype = values.delete_at(0)
              filepath = values.delete_at(0)
              # not all components(rows) have all files; skip if filename "" or nil
              next if filename == '' || filename.nil?

              # skip the file if it doesn't exist at the specified location
              unless File.exist?(filepath)
                puts "[ComponentFromSpreadsheet] ERROR #{filepath} -> File does not exist, will not be included in component xml"
                next # go to the next file
              end
              component_xml.add_file(software_program, version, filepath, filename, filetype)
            else
              raise "Unknown section #{header.name}"
            end
          end

          component_xml.save_tar_gz(false)
        end
      end

      BCL.gather_components(save_path, chunk_size, delete_old_gather)
    end

    private

    def parse_xlsx_worksheet(xlsx_worksheet)
      worksheet = WorksheetStruct.new
      worksheet.name = xlsx_worksheet.row(0)[0] # get A1, order is: row, col
      worksheet.components = []
      puts "[ComponentFromSpreadsheet] Starting parsing components of type #{worksheet.name}"

      # find number of rows, first column should be name, should not be empty
      xlsx_data = []
      xlsx_worksheet.each do |ws|
        xlsx_data << ws
      end

      num_rows = xlsx_data.size
      puts "Number of Rows: #{xlsx_data.size}"
      # num_rows = 2
      # while true
      #   test = xlsx_data[num_rows][0]
      #   if test.nil? or test.empty?
      #     # num_rows -= 1
      #     break
      #   end
      #   num_rows += 1
      # end

      # scan number of columns
      headers = []
      header = nil
      max_col = nil

      xlsx_data[0].each_with_index do |_col, index|
        value1 = xlsx_data[0][index]
        value2 = xlsx_data[1][index]

        if !value1.nil? && !value1.empty?
          unless header.nil?
            headers << header
          end
          header = HeaderStruct.new
          header.name = value1
          header.children = []
        end

        if !value2.nil? && !value2.empty?
          unless header.nil?
            header.children << value2
          end
        end

        if (value1.nil? || value1.empty?) && (value2.nil? || value2.empty?)
          break
        end

        max_col = index
      end

      unless header.nil?
        headers << header
      end

      unless headers.empty?
        headers[0].name = 'description'
      end

      puts "  Found #{num_rows - 2} components"

      components = []
      for i in 2..num_rows - 1 do
        component = ComponentStruct.new
        component.row = i

        # get name
        component.name = xlsx_data[i][0]

        # get uid, if empty set it
        component.uid = xlsx_data[i][1]
        if component.uid.nil? || component.uid.empty?
          component.uid = UUID.new.generate
          puts "#{component.name} uid missing; creating new one"
          xlsx_worksheet.add_cell(i, 1, component.uid)
          @@changed = true

        end

        component.headers = headers
        component.values = xlsx_data[i][0..max_col]
        worksheet.components << component
      end

      @worksheets << worksheet

      puts "[ComponentFromSpreadsheet] Finished parsing components of type #{worksheet.name}"
    end
  end
end
