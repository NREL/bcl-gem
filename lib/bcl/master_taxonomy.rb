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

$have_win32ole = false

if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
  begin
    # apparently this is not a gem
    require 'win32ole'
    mod = WIN32OLE
    $have_win32ole = true
  rescue NameError
    # do not have win32ole
  end
end

module BCL
  # each TagStruct represents a node in the taxonomy tree
  TagStruct = Struct.new(:level_hierarchy, :name, :description, :parent_tag, :child_tags, :terms)

  # each TermStruct represents a row in the master taxonomy
  TermStruct = Struct.new(:first_level, :second_level, :third_level, :level_hierarchy, :name, :description,
                          :abbr, :data_type, :enums, :ip_written, :ip_symbol, :ip_mask, :si_written, :si_symbol, :si_mask,
                          :unit_conversion, :default_val, :min_val, :max_val, :allow_multiple, :row, :tp_include,
                          :tp_required, :tp_use_in_search, :tp_use_in_facets, :tp_show_data_to_data_users, :tp_third_party_testing,
                          :tp_additional_web_dev_info, :tp_additional_data_user_info, :tp_additional_data_submitter_info)

  # class for parsing, validating, and querying the master taxonomy document
  class MasterTaxonomy
    # parse the master taxonomy document
    def initialize(xlsx_path = nil, sort_alpha = false)
      @sort_alphabetical = sort_alpha

      # hash of level_taxonomy to tag
      @tag_hash = {}

      if xlsx_path.nil?
        # load from the current taxonomy
        path = current_taxonomy_path
        puts "Loading current taxonomy from #{path}"
        File.open(path, 'r') do |file|
          @tag_hash = Marshal.load(file)
        end
      else
        xlsx_path = Pathname.new(xlsx_path).realpath.to_s
        puts "Loading taxonomy file #{xlsx_path}"

        # WINDOWS ONLY SECTION BECAUSE THIS USES WIN32OLE
        if $have_win32ole
          begin
            excel = WIN32OLE.new('Excel.Application')
            xlsx = excel.Workbooks.Open(xlsx_path)
            terms_worksheet = xlsx.Worksheets('Terms')
            parse_terms(terms_worksheet)
          ensure
            # not really saving just pretending so don't get prompted on quit
            xlsx.saved = true
            excel.Quit
            WIN32OLE.ole_free(excel)
            excel.ole_free
            xlsx = nil
            excel = nil
            GC.start
          end
        else # if $have_win32ole
          puts "MasterTaxonomy class requires 'win32ole' to parse master taxonomy document."
          puts 'MasterTaxonomy may also be stored and loaded from JSON if your platform does not support win32ole.'
        end # if $have_win32ole
      end
    end

    # save the current taxonomy
    def save_as_current_taxonomy(path = nil)
      unless path
        path = current_taxonomy_path
      end
      puts "Saving current taxonomy to #{path}"
      # this is really not JSON... it is a persisted format of ruby
      File.open(path, 'w') do |file|
        Marshal.dump(@tag_hash, file)
      end
    end

    # write taxonomy to xml
    def write_xml(path, output_type = 'tpex')
      root_tag = @tag_hash['']

      if root_tag.nil?
        puts 'Cannot find root tag'
        return false
      end

      File.open(path, 'w') do |file|
        xml = Builder::XmlMarkup.new(target: file, indent: 2)

        # setup the xml file
        xml.instruct!(:xml, version: '1.0', encoding: 'UTF-8')
        xml.schema('xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance') do
          write_tag_to_xml(root_tag, 0, xml, output_type)
        end
      end
    end

    # get all terms for a given tag
    # this includes terms that are inherited from parent levels
    # e.g. master_taxonomy.get_terms("Space Use.Lighting.Lamp Ballast")
    def get_terms(tag)
      terms = tag.terms

      parent_tag = tag.parent_tag
      until parent_tag.nil?
        terms.concat(parent_tag.terms)
        parent_tag = parent_tag.parent_tag
      end

      # sort the terms as they come out
      result = terms.uniq
      if !@sort_alphabetical
        result = result.sort { |x, y| x.row <=> y.row }
      else
        result = result.sort { |x, y| x.name <=> y.name }
      end

      result
    end

    # check that the given component is conforms with the master taxonomy
    def check_component(component)
      valid = true
      tag = nil

      # see if we can find the component's tag in the taxonomy
      tags = component.tags
      if tags.empty?
        puts '[Check Component ERROR] Component does not have any tags'
        valid = false
      elsif tags.size > 1
        puts '[Check Component ERROR] Component has multiple tags'
        valid = false
      else
        tag = @tag_hash[tags[0].descriptor]
        unless tag
          puts "[Check Component ERROR] Cannot find #{tags[0].descriptor} in the master taxonomy"
          valid = false
        end
      end

      unless tag
        return false
      end

      terms = get_terms(tag)

      # TODO: check for all required attributes
      terms.each do |_term|
        # if term.required
        # make sure we find attribute
        # end
      end

      # check that all attributes are allowed
      component.attributes.each do |attribute|
        term = nil
        terms.each do |t|
          if t.name == attribute.name
            term = t
            break
          end
        end

        unless term
          puts "[Check Component ERROR] Cannot find term for #{attribute.name} in #{tag.level_hierarchy}"
          valid = false
          next
        end

        # TODO: validate value, datatype, units
      end

      valid
    end

    private

    def current_taxonomy_path
      File.dirname(__FILE__) + '/current_taxonomy.json'
    end

    def parse_terms(terms_worksheet)
      # check header
      header_error = validate_terms_header(terms_worksheet)
      if header_error
        fail 'Header Error on Terms Worksheet'
      end

      # add root tag
      root_terms = []
      root_terms << TermStruct.new('', '', '', '', 'OpenStudio Type', 'Type of OpenStudio Object')
      root_terms[0].row = 0
      # root_terms << TermStruct.new()
      root_tag = TagStruct.new('', 'root', 'Root of the taxonomy', nil, [], root_terms)
      @tag_hash[''] = root_tag

      ### puts "**** tag hash: #{@tag_hash}"

      # find number of rows by parsing until hit empty value in first column
      row_num = 3
      loop do
        term = parse_term(terms_worksheet, row_num)
        if term.nil?
          break
        end

        add_term(term)

        row_num += 1
      end

      # sort the tag tree
      sort_tag(root_tag)

      # check the tag tree
      check_tag(root_tag)
    end

    def validate_terms_header(terms_worksheet)
      test_arr = []
      test_arr << { 'name' => 'First Level', 'strict' => true }
      test_arr << { 'name' => 'Second Level', 'strict' => true }
      test_arr << { 'name' => 'Third Level', 'strict' => true }
      test_arr << { 'name' => 'Level Hierarchy', 'strict' => true }
      test_arr << { 'name' => 'Term', 'strict' => true }
      test_arr << { 'name' => 'Abbr', 'strict' => true }
      test_arr << { 'name' => 'Description', 'strict' => true }
      test_arr << { 'name' => 'Data Type', 'strict' => true }
      test_arr << { 'name' => 'Allow Multiple', 'strict' => true }
      test_arr << { 'name' => 'Enumerations', 'strict' => true }
      test_arr << { 'name' => 'IP Units Written Out', 'strict' => true }
      test_arr << { 'name' => 'IP Units Symbol', 'strict' => true }
      test_arr << { 'name' => 'IP Display Mask', 'strict' => true }
      test_arr << { 'name' => 'SI Units Written Out', 'strict' => true }
      test_arr << { 'name' => 'SI Units Symbol', 'strict' => true }
      test_arr << { 'name' => 'SI Display Mask', 'strict' => true }
      test_arr << { 'name' => 'Unit Conversion', 'strict' => true }
      test_arr << { 'name' => 'Default', 'strict' => true }
      test_arr << { 'name' => 'Min', 'strict' => true }
      test_arr << { 'name' => 'Max', 'strict' => true }
      test_arr << { 'name' => 'Source', 'strict' => true }
      test_arr << { 'name' => 'Review State', 'strict' => true }
      test_arr << { 'name' => 'General Comments', 'strict' => true }
      test_arr << { 'name' => 'Requested By / Project', 'strict' => true }
      test_arr << { 'name' => 'Include in TPE', 'strict' => false }
      test_arr << { 'name' => 'Required for Adding a New Product', 'strict' => false }
      test_arr << { 'name' => 'Use as a Column Header in Search Results', 'strict' => false }
      test_arr << { 'name' => 'Allow Users to Filter with this Facet', 'strict' => false }
      test_arr << { 'name' => 'Show Data to Data Users', 'strict' => false }
      test_arr << { 'name' => 'Additional Instructions for Web Developers', 'strict' => false }
      test_arr << { 'name' => 'Related Third Party Testing Standards', 'strict' => false }
      test_arr << { 'name' => 'Additional Guidance to Data Submitters', 'strict' => false }
      test_arr << { 'name' => 'Additional Guidance to Data Users', 'strict' => false }

      parse = true
      col = 1
      while parse
        if terms_worksheet.Columns(col).Rows(2).Value.nil? || col > test_arr.size
          parse = false
        else
          unless terms_worksheet.Columns(col).Rows(2).Value == test_arr[col - 1]['name']
            if test_arr[col - 1]['strict']
              fail "[ERROR] Header does not match: #{col}: '#{terms_worksheet.Columns(col).Rows(2).Value} <> #{test_arr[col - 1]['name']}'"
            else
              puts "[WARNING] Header does not match: #{col}: '#{terms_worksheet.Columns(col).Rows(2).Value} <> #{test_arr[col - 1]['name']}'"
            end
          end
        end
        col += 1
      end
    end

    def parse_term(terms_worksheet, row)
      term = TermStruct.new
      term.row = row
      term.first_level = terms_worksheet.Columns(1).Rows(row).Value
      term.second_level = terms_worksheet.Columns(2).Rows(row).Value
      term.third_level = terms_worksheet.Columns(3).Rows(row).Value
      term.level_hierarchy = terms_worksheet.Columns(4).Rows(row).Value
      term.name = terms_worksheet.Columns(5).Rows(row).Value
      term.abbr = terms_worksheet.Columns(6).Rows(row).Value
      term.description = terms_worksheet.Columns(7).Rows(row).Value
      term.data_type = terms_worksheet.Columns(8).Rows(row).Value
      term.allow_multiple = terms_worksheet.Columns(9).Rows(row).Value
      term.enums = terms_worksheet.Columns(10).Rows(row).Value
      term.ip_written = terms_worksheet.Columns(11).Rows(row).Value
      term.ip_symbol = terms_worksheet.Columns(12).Rows(row).Value
      term.ip_mask = terms_worksheet.Columns(13).Rows(row).Value
      term.si_written = terms_worksheet.Columns(14).Rows(row).Value
      term.si_symbol = terms_worksheet.Columns(15).Rows(row).Value
      term.si_mask = terms_worksheet.Columns(16).Rows(row).Value
      term.unit_conversion = terms_worksheet.Columns(17).Rows(row).Value
      term.default_val = terms_worksheet.Columns(18).Rows(row).Value
      term.min_val = terms_worksheet.Columns(19).Rows(row).Value
      term.max_val = terms_worksheet.Columns(20).Rows(row).Value

      # custom TPex Columns
      term.tp_include = terms_worksheet.Columns(25).Rows(row).Value
      term.tp_required = terms_worksheet.Columns(26).Rows(row).Value
      term.tp_use_in_search = terms_worksheet.Columns(27).Rows(row).Value
      term.tp_use_in_facets = terms_worksheet.Columns(28).Rows(row).Value
      term.tp_show_data_to_data_users = terms_worksheet.Columns(29).Rows(row).Value
      term.tp_additional_web_dev_info = terms_worksheet.Columns(30).Rows(row).Value
      term.tp_third_party_testing = terms_worksheet.Columns(31).Rows(row).Value
      term.tp_additional_data_submitter_info = terms_worksheet.Columns(32).Rows(row).Value
      term.tp_additional_data_user_info = terms_worksheet.Columns(33).Rows(row).Value

      # trigger to quit parsing the xcel doc
      if term.first_level.nil? || term.first_level.empty?
        return nil
      end

      term
    end

    def add_term(term)
      level_hierarchy = term.level_hierarchy

      # create the tag
      tag = @tag_hash[level_hierarchy]

      if tag.nil?
        tag = create_tag(level_hierarchy, term.description)
      end

      if term.name.nil? || term.name.strip.empty?
        # this row is really about the tag
        tag.description = term.description

      else
        # this row is about a term
        unless validate_term(term)
          return nil
        end

        tag.terms = [] if tag.terms.nil?
        tag.terms << term
      end
    end

    def create_tag(level_hierarchy, tag_description = '')
      # puts "create_tag called for #{level_hierarchy}"

      parts = level_hierarchy.split('.')

      name = parts[-1]
      parent_level = parts[0..-2].join('.')

      parent_tag = @tag_hash[parent_level]
      if parent_tag.nil?
        parent_tag = create_tag(parent_level)
      end

      description = tag_description
      child_tags = []
      terms = []
      tag = TagStruct.new(level_hierarchy, name, description, parent_tag, child_tags, terms)

      parent_tag.child_tags << tag

      @tag_hash[level_hierarchy] = tag

      tag
    end

    def sort_tag(tag)
      # tag.terms = tag.terms.sort {|x, y| x.level_hierarchy <=> y.level_hierarchy}
      tag.child_tags = tag.child_tags.sort { |x, y| x.level_hierarchy <=> y.level_hierarchy }
      tag.child_tags.each { |child_tag| sort_tag(child_tag) }

      # tag.terms = tag.terms.sort {|x, y| x.name <=> y.name}
      # tag.child_tags = tag.child_tags.sort {|x, y| x.name <=> y.name}
      # tag.child_tags.each {|child_tag| sort_tag(child_tag) }
    end

    def check_tag(tag)
      if tag.description.nil? || tag.description.empty?
        puts "[check_tag] tag '#{tag.level_hierarchy}' has no description"
      end

      tag.terms.each { |term| check_term(term) }
      tag.child_tags.each { |child_tag| check_tag(child_tag) }
    end

    def validate_term(term)
      valid = true

      parts = term.level_hierarchy.split('.')

      if parts.empty?
        puts "Hierarchy parts empty, #{term.level_hierarchy}"
        valid = false
      end

      if parts.size >= 1 && !term.first_level == parts[0]
        puts "First level '#{term.first_level}' does not match level hierarchy '#{term.level_hierarchy}', skipping term"
        valid = false
      end

      if parts.size >= 2 && !term.second_level == parts[1]
        puts "Second level '#{term.second_level}' does not match level hierarchy '#{term.level_hierarchy}', skipping term"
        valid = false
      end

      if parts.size >= 3 && !term.third_level == parts[2]
        puts "Third level '#{term.third_level}' does not match level hierarchy '#{term.level_hierarchy}', skipping term"
        valid = false
      end

      if parts.size > 3
        puts "Hierarchy cannot have more than 3 parts '#{term.level_hierarchy}', skipping term"
        valid = false
      end

      unless term.data_type.nil?
        valid_types = %w(double integer enum file string autocomplete)
        if (term.data_type.downcase != term.data_type) || !valid_types.include?(term.data_type)
          puts "[ERROR] Term '#{term.name}' does not have a valid data type with '#{term.data_type}'"
        end

        if term.data_type.downcase == 'enum'
          if term.enums.nil? || term.enums == '' || term.enums.downcase == 'no enum found'
            puts "[ERROR] Term '#{term.name}' does not have valid enumerations"
          end
        end
      end

      valid
    end

    def check_term(term)
      if term.description.nil? || term.description.empty?
        # puts "[check_term] term '#{term.level_hierarchy}.#{term.name}' has no description"
      end
    end

    # write term to xml
    def write_terms_to_xml(tag, xml, output_type)
      terms = get_terms(tag)
      if terms.size > 0
        terms.each do |term|
          xml.term do
            xml.name term.name
            xml.abbr term.abbr unless term.abbr.nil?
            xml.description term.description unless term.description.nil?
            xml.data_type term.data_type unless term.data_type.nil?
            xml.allow_multiple term.allow_multiple unless term.allow_multiple.nil?

            if !term.enums.nil? && term.enums != ''
              xml.enumerations do
                out = term.enums.split('|')
                out.sort! if @sort_alphabetical
                out.each do |enum|
                  xml.enumeration enum
                end
              end
            end
            xml.ip_written term.ip_written unless term.ip_written.nil?
            xml.ip_symbol term.ip_symbol unless term.ip_symbol.nil?
            xml.ip_mask term.ip_mask unless term.ip_mask.nil?
            xml.si_written term.si_written unless term.si_written.nil?
            xml.si_symbol term.si_symbol unless term.si_symbol.nil?
            xml.si_mask term.si_mask unless term.si_mask.nil?
            xml.row term.row unless term.row.nil?
            xml.unit_conversion term.unit_conversion unless term.unit_conversion.nil?
            xml.default_val term.default_val unless term.default_val.nil?
            xml.min_val term.min_val unless term.min_val.nil?
            xml.max_val term.max_val unless term.max_val.nil?

            if output_type == 'tpex'
              xml.tp_include term.tp_include unless term.tp_include.nil?
              xml.tp_required term.tp_required unless term.tp_required.nil?
              xml.tp_use_in_search term.tp_use_in_search unless term.tp_use_in_search.nil?
              xml.tp_use_in_facets term.tp_use_in_facets unless term.tp_use_in_facets.nil?
              xml.tp_show_data_to_data_users term.tp_show_data_to_data_users unless term.tp_show_data_to_data_users.nil?
              xml.tp_third_party_testing term.tp_third_party_testing unless term.tp_third_party_testing.nil?
              xml.tp_additional_web_dev_info term.tp_additional_web_dev_info unless term.tp_additional_web_dev_info.nil?
              xml.tp_additional_data_user_info term.tp_additional_data_user_info unless term.tp_additional_data_user_info.nil?
              xml.tp_additional_data_submitter_info term.tp_additional_data_submitter_info unless term.tp_additional_data_submitter_info.nil?
            end
          end
        end
      end
    end

    # write a tag to xml
    def write_tag_to_xml(tag, level, xml, output_type)
      level_string = "level_#{level}"
      xml.tag!(level_string) do
        s_temp = tag.name
        xml.name s_temp
        xml.description tag.description

        level += 1

        if tag.child_tags.size == 0
          write_terms_to_xml(tag, xml, output_type)
        end

        child_tags = tag.child_tags
        child_tags.each do |child_tag|
          write_tag_to_xml(child_tag, level, xml, output_type)
        end
      end
    end
  end
end # module BCL
