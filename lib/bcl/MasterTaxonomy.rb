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
require 'builder'  #gem install builder (creates xml files)

$have_win32ole = false
begin
  # apparently this is not a gem
  require 'win32ole'
  mod = WIN32OLE
  $have_win32ole = true
rescue NameError
  # do not have win32ole
end

module BCL

# each TagStruct represents a node in the taxonomy tree
TagStruct = Struct.new(:level_hierarchy, :name, :description, :parent_tag, :child_tags, :terms)

# each TermStruct represents a row in the master taxonomy
TermStruct = Struct.new(:first_level, :second_level, :third_level, :level_hierarchy, :name, :description, 
					    :abbr, :data_type, :enums, :ip_written, :ip_symbol, :ip_mask, :si_written, :si_symbol, :si_mask)

# class for parsing, validating, and querying the master taxonomy document
class MasterTaxonomy

  # parse the master taxonomy document
  def initialize(xlsx_path = nil)
	@sort_terms_on_write = true
  
    # hash of level_taxonomy to tag
    @tag_hash = Hash.new
  
    if xlsx_path.nil?
      # load from the current taxonomy 
      path = current_taxonomy_path
      puts "Loading current taxonomy from #{path}"
      File.open(path, 'r') do |file|
        @tag_hash = Marshal.load(file)
      end
    else
      xlsx_path = Pathname.new(xlsx_path).realpath.to_s

      # WINDOWS ONLY SECTION BECAUSE THIS USES WIN32OLE
      if $have_win32ole
        begin
          excel = WIN32OLE::new('Excel.Application')
          xlsx = excel.Workbooks.Open(xlsx_path)
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
      else # if $have_win32ole
        puts "MasterTaxonomy class requires 'win32ole' to parse master taxonomy document."
        puts "MasterTaxonomy may also be stored and loaded from JSON if your platform does not support win32ole."
      end # if $have_win32ole
    end
  end

  # save the current taxonomy
  def save_as_current_taxonomy(path = nil)
    if not path
      path = current_taxonomy_path
    end
    puts "Saving current taxonomy to #{path}"
	# this is really not JSON... it is a persisted format of ruby
    File.open(path, 'w') do |file|
      Marshal.dump(@tag_hash, file)
    end
  end
  
  # write taxonomy to xml
  def write_xml(path)
  
    root_tag = @tag_hash[""]
    
    if root_tag.nil?
      puts "Cannot find root tag"
      return false
    end

    File.open(path, 'w') do |file|
      xml = Builder::XmlMarkup.new(:target => file, :indent=>2)

      #setup the xml file
      xml.instruct!(:xml, :version=>"1.0", :encoding=>"UTF-8")
      xml.schema("xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance") {
        write_tag_to_xml(root_tag, xml)       
      }
    end
    
  end
  
  # get all terms for a given tag
  # this includes terms that are inherited from parent levels
  # e.g. master_taxonomy.get_terms("Space Use.Lighting.Lamp Ballast")
  def get_terms(tag)
    
    terms = tag.terms
    
    parent_tag = tag.parent_tag
    while not parent_tag.nil?
      terms.concat(parent_tag.terms)
      parent_tag = parent_tag.parent_tag
    end

	#sort the terms as they come out
	result = terms.reverse.uniq
	if @sort_terms_on_write
      result = result.sort {|x, y| x.name <=> y.name}
	end
	 
    return result
  end
  
  # check that the given component is conforms with the master taxonomy
  def check_component(component)
    valid = true
    tag = nil
    
    # see if we can find the component's tag in the taxonomy
    tags = component.tags
    if tags.empty?
      puts "[Check Component ERROR] Component does not have any tags"
      valid = false
    elsif tags.size > 1
      puts "[Check Component ERROR] Component has multiple tags"
      valid = false
    else
      tag = @tag_hash[tags[0].descriptor]
      if not tag
        puts "[Check Component ERROR] Cannot find #{tags[0].descriptor} in the master taxonomy"
        valid = false
      end
    end
    
    if not tag
      return false
    end
    
    terms = get_terms(tag)
    
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
        if t.name == attribute.name
          term = t
          break
        end
      end
      
      if not term
        puts "[Check Component ERROR] Cannot find term for #{attribute.name} in #{tag.level_hierarchy}"
        valid = false
        next
      end
      
      # todo: validate value, datatype, units
      
    end
    
    return valid
  end
  
  private
  
  def current_taxonomy_path
    return File.dirname(__FILE__) + "/current_taxonomy.json"
  end

  def parse_terms(terms_worksheet)
  
    # check header
    header_error = validate_terms_header(terms_worksheet)
    if header_error
      raise "Header Error on Terms Worksheet"
    end
    
    # add root tag
    root_terms = []
    root_terms << TermStruct.new("", "", "", "", "OpenStudio Type", "Type of OpenStudio Object")
    root_tag = TagStruct.new("", "root", "Root of the taxonomy", nil, [], root_terms)
    @tag_hash[""] = root_tag

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
    
    # sort the tag tree
    sort_tag(root_tag)
    
    # check the tag tree
    check_tag(root_tag)
    
  end
  
  
  def validate_terms_header(terms_worksheet)
    header_error = false
    
    first_level      = terms_worksheet.Range("A2").Value
    second_level     = terms_worksheet.Range("B2").Value
    third_level      = terms_worksheet.Range("C2").Value
    level_hierarchy  = terms_worksheet.Range("D2").Value
    name             = terms_worksheet.Range("E2").Value
    abbr             = terms_worksheet.Range("F2").Value
    description      = terms_worksheet.Range("G2").Value
	data_type		 = terms_worksheet.Range("I2").Value
	enums			 = terms_worksheet.Range("J2").Value
	ip_written		 = terms_worksheet.Range("K2").Value
	ip_symbol		 = terms_worksheet.Range("L2").Value
	ip_mask			 = terms_worksheet.Range("M2").Value
	si_written		 = terms_worksheet.Range("N2").Value
	si_symbol		 = terms_worksheet.Range("O2").Value
	si_mask			 = terms_worksheet.Range("P2").Value
	
    header_error = true if not first_level == "First Level"
    header_error = true if not second_level == "Second Level"
    header_error = true if not third_level == "Third Level"
    header_error = true if not level_hierarchy == "Level Hierarchy"
    header_error = true if not name  == "Term"
    header_error = true if not abbr  == "Abbr"
    header_error = true if not description  == "Description"
	header_error = true if not data_type  == "Data Type"
	header_error = true if not enums  == "Enumerations"
	header_error = true if not ip_written  == "IP Units Written Out"
	header_error = true if not ip_symbol  == "IP Units Symbol"
	header_error = true if not ip_mask  == "IP Display Mask"
	header_error = true if not si_written  == "SI Units Written Out"
	header_error = true if not si_symbol  == "SI Units Symbol"
	header_error = true if not si_mask  == "SI Display Mask"
    
    return header_error
  end
  
  def parse_term(terms_worksheet, row)
 
    term = TermStruct.new
    term.first_level      	= terms_worksheet.Range("A#{row}").Value
    term.second_level     	= terms_worksheet.Range("B#{row}").Value
    term.third_level      	= terms_worksheet.Range("C#{row}").Value
    term.level_hierarchy  	= terms_worksheet.Range("D#{row}").Value
    term.name             	= terms_worksheet.Range("E#{row}").Value
    term.abbr             	= terms_worksheet.Range("F#{row}").Value
    term.description      	= terms_worksheet.Range("G#{row}").Value
	term.data_type		  	= terms_worksheet.Range("I#{row}").Value
	term.enums    		  	= terms_worksheet.Range("J#{row}").Value
	term.ip_written			= terms_worksheet.Range("K#{row}").Value
	term.ip_symbol			= terms_worksheet.Range("L#{row}").Value
	term.ip_mask			= terms_worksheet.Range("M#{row}").Value
	term.si_written			= terms_worksheet.Range("N#{row}").Value
	term.si_symbol			= terms_worksheet.Range("O#{row}").Value
	term.si_mask			= terms_worksheet.Range("P#{row}").Value

	
	
	
    # trigger to quit parsing the xcel doc
    if term.first_level.nil? or term.first_level.empty?
      return nil
    end
    
    return term
  end
  
  def add_term(term)
  
    level_hierarchy = term.level_hierarchy
    
    #puts "add_term called for #{level_hierarchy}"
    
    # create the tag
    tag = @tag_hash[level_hierarchy]
    if tag.nil?
      tag = create_tag(level_hierarchy)
    end
    
    if term.name.nil? or term.name.strip.empty?
      # this row is really about the tag
      tag.description = term.description
    else
      # this row is about a term
      if not validate_term(term)
        return nil
      end
    
      tag.terms = [] if tag.terms.nil?
      tag.terms << term
    end
  end
  
  def create_tag(level_hierarchy)
  
    #puts "create_tag called for #{level_hierarchy}"
  
    parts = level_hierarchy.split('.')
    
    name = parts[-1]
    parent_level = parts[0..-2].join('.')
    
    parent_tag = @tag_hash[parent_level]
    if parent_tag.nil?
      parent_tag = create_tag(parent_level)
    end
    
    description = ""
    child_tags = []
    terms = []
    tag = TagStruct.new(level_hierarchy, name, description, parent_tag, child_tags, terms)
    
    parent_tag.child_tags << tag
    
    @tag_hash[level_hierarchy] = tag
    
    return tag
  end
  
  def sort_tag(tag)
    tag.terms = tag.terms.sort {|x, y| x.name <=> y.name}
    tag.child_tags = tag.child_tags.sort {|x, y| x.name <=> y.name}
    tag.child_tags.each {|child_tag| sort_tag(child_tag) }
  end
  
  def check_tag(tag)
    
    if tag.description.nil? or tag.description.empty?
      #puts "tag '#{tag.level_hierarchy}' has no description"
    end
	
    tag.terms.each {|term| check_term(term) }
    tag.child_tags.each {|child_tag| check_tag(child_tag) }
  end
  
  def validate_term(term)
    valid = true

    parts = term.level_hierarchy.split('.')
    
    if parts.empty?
      puts "Hierarchy parts empty, #{term.level_hierarchy}"
      valid = false
    end
    
    if parts.size >= 1 and not term.first_level == parts[0]
      puts "First level '#{term.first_level}' does not match level hierarchy '#{term.level_hierarchy}', skipping term"
      valid = false
    end
    
    if parts.size >= 2 and not term.second_level == parts[1]
      puts "Second level '#{term.second_level}' does not match level hierarchy '#{term.level_hierarchy}', skipping term"
      valid = false
    end
    
    if parts.size >= 3 and not term.third_level == parts[2]
      puts "Third level '#{term.third_level}' does not match level hierarchy '#{term.level_hierarchy}', skipping term"
      valid = false
    end
    
    if parts.size > 3
      puts "Hierarchy cannot have more than 3 parts '#{term.level_hierarchy}', skipping term"
      valid = false
    end
    
	if !term.data_type.nil?
	  valid_types = ["double", "integer", "enum", "file", "string"]
	  if (term.data_type.downcase != term.data_type) || !valid_types.include?(term.data_type) 
 	    puts "[ERROR] Term '#{term.name}' does not have a valid data type with '#{term.data_type}'"
	  end
	  
	  if term.data_type.downcase == "enum"
	    if term.enums.nil? || term.enums == "" || term.enums.downcase == "no enum found"
		  puts "[ERROR] Term '#{term.name}' does not have valid enumerations"
		end
	  end
	end
    
    return valid
  end
  
  def check_term(term)
    if term.description.nil? or term.description.empty?
      #puts "term '#{term.level_hierarchy}.#{term.name}' has no description"
    end
  end
  
  # write term to xml
  def write_terms_to_xml(tag, xml)
    terms = get_terms(tag) 
	if terms.size > 0
      terms.each do |term|
	    xml.term {
  	      xml.name term.name
	      xml.abbr term.abbr if !term.abbr.nil? 
		  xml.description term.description if !term.description.nil?
		  xml.data_type term.data_type if !term.data_type.nil?
		  xml.enumerations term.enums if !term.enums.nil? && term.enums != ""
		  xml.ip_written term.ip_written if !term.ip_written.nil?
		  xml.ip_symbol term.ip_symbol if !term.ip_symbol.nil?
		  xml.ip_mask term.ip_mask if !term.ip_mask.nil?
		  xml.si_written term.si_written if !term.si_written.nil?
		  xml.si_symbol term.si_symbol if !term.si_symbol.nil?
		  xml.si_mask term.si_mask if !term.si_mask.nil?
				 
	    }
	  end
	end
  end
  
  # write a tag to xml
  def write_tag_to_xml(tag, xml)
	xml.tag {
	  s_temp = tag.name  #.gsub("Electric Lighting","Space Use")
	  xml.name s_temp
	  
	  #puts "Writing Tag Name: #{tag.name}"
	 
	  	  
	  if tag.child_tags.size == 0
	    write_terms_to_xml(tag, xml)
	  end
	  
	  child_tags = tag.child_tags
      child_tags.each do |child_tag|
        write_tag_to_xml(child_tag, xml)
      end
		 
	}
  end
  
end

end # module BCL


