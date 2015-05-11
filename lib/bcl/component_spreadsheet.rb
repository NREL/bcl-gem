######################################################################
#  Copyright (c) 2008-2014, Alliance for Sustainable Energy.
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

# Converts a custom Excel spreadsheet format to BCL components for upload
# Format of the Excel spreadsheet is documented in /doc/ComponentSpreadsheet.docx

if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
  begin
    # apparently this is not a gem (todo: need to remove and replace with roo)
    require 'win32ole'
    mod = WIN32OLE
    $have_win32ole = true
  rescue NameError
    # do not have win32ole
  end
end

module BCL
  class ComponentSpreadsheet
    public

    # WINDOWS ONLY SECTION BECAUSE THIS USES WIN32OLE
    if $have_win32ole

      # initialize with Excel spreadsheet to read
      def initialize(xlsx_path, worksheet_names = ['all'])
        @xlsx_path = Pathname.new(xlsx_path).realpath.to_s
        @worksheets = []

        begin

          excel = WIN32OLE.new('Excel.Application')

          xlsx = excel.Workbooks.Open(@xlsx_path)

          # by default, operate on all worksheets
          if worksheet_names == ['all']
            xlsx.Worksheets.each do |xlsx_worksheet|
              parse_xlsx_worksheet(xlsx_worksheet)
            end
          else # if specific worksheets are specified, operate on them
            worksheet_names.each do |worksheet_name|
              parse_xlsx_worksheet(xlsx.Worksheets(worksheet_name))
            end
          end

          # save spreadsheet if changes have been made
          if xlsx.saved == true
            # puts "[ComponentSpreadsheet] Spreadsheet unchanged; not saving"
          else
            xlsx.Save
            puts '[ComponentSpreadsheet] Spreadsheet changes saved'
          end

        ensure

          excel.Quit
          WIN32OLE.ole_free(excel)
          excel.ole_free
          xlsx = nil
          excel = nil
          GC.start

        end
      end

    else # if $have_win32ole

      # parse the master taxonomy document
      def initialize(_xlsx_path)
        puts "ComponentSpreadsheet class requires 'win32ole' to parse the component spreadsheet."
        puts 'ComponentSpreadsheet may also be stored and loaded from JSON if your platform does not support win32ole.'
      end

    end # if $have_win32ole

    def save(save_path, chunk_size = 1000, delete_old_gather = false)
      # load master taxonomy to validate components
      taxonomy = BCL::MasterTaxonomy.new

      # FileUtils.rm_rf(save_path) if File.exists?(save_path) and File.directory?(save_path)

      @worksheets.each do |worksheet|
        worksheet.components.each do |component|
          component_xml = Component.new("#{save_path}/components")
          component_xml.name = component.name
          component_xml.uid = component.uid
          component_xml.comp_version_id = component.version_id

          # this tag is how we know where this goes in the taxonomy
          component_xml.add_tag(worksheet.name)

          values = component.values[0]
          component.headers.each do |header|
            if /description/i.match(header.name)

              name = values.delete_at(0)
              uid = values.delete_at(0)
              version_id = values.delete_at(0)
              description = values.delete_at(0)
              fidelity_level = values.delete_at(0).to_int
              # name, uid, and version_id already processed
              component_xml.description = description
              component_xml.fidelity_level = fidelity_level

            elsif /provenance/i.match(header.name)

              author = values.delete_at(0)
              datetime = values.delete_at(0)
              if datetime.nil?
                # puts "[ComponentSpreadsheet] WARNING missing the date in the datetime column in the spreadsheet - assuming today"
                datetime = DateTime.new
              else
                datetime = DateTime.parse(datetime)
              end

              comment = values.delete_at(0)
              component_xml.add_provenance(author.to_s, datetime.to_s, comment.to_s)

            elsif /tag/i.match(header.name)

              value = values.delete_at(0)
              component_xml.add_tag(value)

            elsif /attribute/i.match(header.name)

              value = values.delete_at(0)
              name = header.children[0]
              units = ''
              if match_data = /(.*)\((.*)\)/.match(name)
                name = match_data[1].strip
                units = match_data[2].strip
              end
              component_xml.add_attribute(name, value, units)

            elsif /source/i.match(header.name)

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

            elsif /file/i.match(header.name)

              software_program = values.delete_at(0)
              version = values.delete_at(0)
              filename = values.delete_at(0)
              filetype = values.delete_at(0)
              filepath = values.delete_at(0)
              # not all components(rows) have all files; skip if filename "" or nil
              next if filename == '' || filename.nil?
              # skip the file if it doesn't exist at the specified location
              unless File.exist?(filepath)
                puts "[ComponentSpreadsheet] ERROR #{filepath} -> File does not exist, will not be included in component xml"
                next # go to the next file
              end
              component_xml.add_file(software_program, version, filepath, filename, filetype)

            else
              fail "Unknown section #{header.name}"

            end
          end

          taxonomy.check_component(component_xml)

          component_xml.save_tar_gz(false)
        end
      end

      BCL.gather_components(save_path, chunk_size, delete_old_gather)
    end

    private

    def parse_xlsx_worksheet(xlsx_worksheet)
      worksheet = WorksheetStruct.new
      worksheet.name = xlsx_worksheet.Range('A1').Value
      worksheet.components = []
      puts "[ComponentSpreadsheet] Starting parsing components of type #{worksheet.name}"

      # find number of rows, first column should be name, should not be empty
      num_rows = 1
      loop do
        test = xlsx_worksheet.Range("A#{num_rows}").Value
        if test.nil? || test.empty?
          num_rows -= 1
          break
        end
        num_rows += 1
      end

      # scan number of columns
      headers = []
      header = nil
      max_col = nil
      xlsx_worksheet.Columns.each do |col|
        value1 = col.Rows('1').Value
        value2 = col.Rows('2').Value

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

        matchdata = /^\$(.+):/.match(col.Address)
        max_col = matchdata[1]
      end

      unless header.nil?
        headers << header
      end

      unless headers.empty?
        headers[0].name = 'description'
      end

      puts "  Found #{num_rows - 2} components"

      components = []
      for i in 3..num_rows do
        component = ComponentStruct.new
        component.row = i

        # get name
        component.name = xlsx_worksheet.Range("A#{i}").value

        # get uid, if empty set it
        component.uid = xlsx_worksheet.Range("B#{i}").value
        if component.uid.nil? || component.uid.empty?
          component.uid = UUID.new.generate
          puts "#{component.name} uid missing; creating new one"
          xlsx_worksheet.Range("B#{i}").value = component.uid
        end

        # get version_id, if empty set it
        component.version_id = xlsx_worksheet.Range("C#{i}").value
        if component.version_id.nil? || component.version_id.empty?
          component.version_id = UUID.new.generate
          puts "#{component.name} version id missing; creating new one"
          xlsx_worksheet.Range("C#{i}").value = component.version_id
        end

        component.headers = headers
        component.values = xlsx_worksheet.Range("A#{i}:#{max_col}#{i}").value
        worksheet.components << component
      end

      @worksheets << worksheet

      puts "[ComponentSpreadsheet] Finished parsing components of type #{worksheet.name}"
    end
  end
end # module BCL
