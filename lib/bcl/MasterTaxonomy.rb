######################################################################
#  Copyright (c) 2008-2010, Alliance for Sustainable Energy.  
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

require 'rubygems'
require 'pathname'
require 'fileutils'

# gem install win32ole
#WINDOWS ONLY SECTION BECAUSE THIS USES WIN32OLE
if /mswin/.match(RUBY_PLATFORM) or /mingw/.match(RUBY_PLATFORM) and require('win32ole')

module BCL

# each TermStruct represents a row in the master taxonomy
# if the :term member is empty then this term represents a placeholder tag in the hierarchy
# if the :term member is not empty then this term represents an attribute a component of this type may have
TermStruct = Struct.new(:first_level, :second_level, :third_level, :level_hierarchy, :term)

# class for parsing, validating, and querying the master taxonomy document
class MasterTaxonomy

  # parse the master taxonomy document
  def initialize(xlsx_path)
  
    @xlsx_path = Pathname.new(xlsx_path).realpath.to_s
    
    # hash of level_taxonomy to array of terms
    @term_hash = Hash.new
    
    begin
    
      excel = WIN32OLE::new('Excel.Application')
  
      xlsx = excel.Workbooks.Open(@xlsx_path)
      
      terms_worksheet = xlsx.Worksheets("Terms")
      parse_terms(terms_worksheet)

    ensure
    
      # not really saving just pretending so don't get prompted on quit
      xlsx.saved = true
      
      excel.Quit
      WIN32OLE.ole_free(excel)
      excel.ole_free
      xlsx=nil
      excel=nil
      GC.start
      
    end
  end
  
  # get all terms for a given level hierarchy
  # this includes terms that are inherited from parent levels
  # e.g. master_taxonomy.get_terms("Space Use.Lighting.Lamp Ballast")
  def get_terms(level_hierarchy)
    
    terms = []
    parts = level_hierarchy.split('.')
    
    (0...parts.size).each do |i|
      this_level = parts[0..i].join('.')
      if this_terms = @term_hash[this_level]
        terms = terms.concat(this_terms)
      end
    end

    return terms
  end
  
  # validate the master taxonomy is correct, prints any errors to stdout
  def validate
    
    valid = true
  
    # loop over the terms hash
    @term_hash.each_pair do |level_hierarchy, terms|
    
      if level_hierarchy.nil? 
        puts "Nil tag not allowed in master taxonomy"
        valid = false
        next
      elsif level_hierarchy.empty?
        puts "Empty tag not allowed in master taxonomy"
        valid = false
        next
      end
    
      parts = level_hierarchy.split('.')
      
      # check that entry for parent level exists
      parent_level = parts[0..-2].join('.')
      if not parent_level.empty?
        if not @term_hash[parent_level]
          puts "No parent tag defined for '#{level_hierarchy}'"
          valid = false
        end
      end
    
      # check that there is an empty term indicating the placeholder for this hierarchy tag
      placeholder_term = nil
      terms.each do |term| 
        if term.term == ""
          if placeholder_term
            puts "Duplicate placeholder tags defined for '#{level_hierarchy}'"
            valid = false
          else
            placeholder_term = term
          end
        else
          valid = false if not validate_term(term)
        end
      end
      
      # should be one placeholder term for each level in the hierarchy
      if not placeholder_term
        puts "No placeholder tag defined for '#{level_hierarchy}'"
        valid = false
      else
        valid = false if not validate_placeholder(placeholder_term)
      end
      
    end
    
    return valid
  end
  
  # check that the given component is conforms with the master taxonomy
  def check_component(component)
    valid = true
    
    terms = nil
    
    # see if we can find the component's tag in the taxonomy
    tags = component.tags
    if tags.empty?
      puts "Component does not have any tags"
      valid = false
    elsif tags.size > 1
      puts "Component has multiple tags"
      valid = false
    else
      terms = get_terms(tags[0].descriptor)
      if not terms
        puts "Cannot find #{tags[0].descriptor} in the master taxonomy"
        valid = false
      end
    end
    
    if not terms
      return false
    end
    
    # todo: check for all required attributes
    terms.each do |term|
      #if term.required
      # make sure we find attribute
      #end
    end
    
    # check that all attributes are allowed
    component.attributes.each do |attribute|
      
      term = nil
      terms.each do |t|
        if term.term == attribute.name
          term = t
          break
        end
      end
      
      if not term
        puts "Cannot find term for #{attribute.name} in #{tags[0].descriptor}"
        valid = false
        next
      end
      
      # todo: validate value, datatype, units
      
    end
    
    return valid
  end
  
  private

  def parse_terms(terms_worksheet)
  
    # check header
    header_error = validate_terms_header(terms_worksheet)
    if header_error
      raise "Header Error on Terms Worksheet"
    end
    
    # find number of rows by parsing until hit empty value in first column
    row_num = 3
    while true do 
      term = parse_term(terms_worksheet, row_num)
      if term.nil?
        break
      end
      
      add_term(term)

      row_num += 1
    end
    
  end
  
  def validate_terms_header(terms_worksheet)
    header_error = false
    
    term = parse_term(terms_worksheet, 2)
    
    header_error = true if not term
    header_error = true if not term.first_level == "First Level"
    header_error = true if not term.second_level == "Second Level"
    header_error = true if not term.third_level == "Third Level"
    header_error = true if not term.level_hierarchy == "Level Hierarchy"
    header_error = true if not term.term  == "Term"
    
    return header_error
  end
  
  def parse_term(terms_worksheet, row)
 
    term = TermStruct.new
    term.first_level      = terms_worksheet.Range("A#{row}").Value
    term.second_level     = terms_worksheet.Range("B#{row}").Value
    term.third_level      = terms_worksheet.Range("C#{row}").Value
    term.level_hierarchy  = terms_worksheet.Range("D#{row}").Value
    term.term             = terms_worksheet.Range("E#{row}").Value
    
    if term.first_level.nil? or term.first_level.empty?
      return nil
    end
    
    return term

  end
  
  def add_term(term)
    @term_hash[term.level_hierarchy] = [] if @term_hash[term.level_hierarchy].nil?
    @term_hash[term.level_hierarchy] << term
  end
  
  def validate_term(term)
    valid = true
    
    valid = false if not validate_parts(term)
    
    # todo: check description, data type, enumerations, units, source, author
    
    return valid
  end
  
  def validate_placeholder(term)
    valid = true
    
    valid = false if not validate_parts(term)
    
    # todo: check description, data type, enumerations, units, source, author
    
    return valid
  end
  
  def validate_parts(term)
    valid = true
    
    parts = term.level_hierarchy.split('.')
    
    if parts.empty?
      puts "Hierarchy parts empty, #{term.level_hierarchy}"
      valid = false
    end
    
    if parts.size >= 1 and not term.first_level == parts[0]
      puts "First level does not match level hierarchy, #{term.level_hierarchy}"
      valid = false
    end
    
    if parts.size >= 2 and not term.second_level == parts[1]
      puts "Second level does not match level hierarchy, #{term.level_hierarchy}"
      valid = false
    end
    
    if parts.size >= 3 and not term.third_level == parts[2]
      puts "Third level does not match level hierarchy, #{term.level_hierarchy}"
      valid = false
    end
    
    if parts.size > 3
      puts "Hierarchy cannot have more than 3 parts, #{term.level_hierarchy}"
      valid = false
    end

    return valid
  end

end

end # module BCL

end # if mswin32 and require('win32ole')
