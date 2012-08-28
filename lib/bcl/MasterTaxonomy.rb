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
TagStruct = Struct.new(:level_hierarchy, :name, :parent_tag, :child_tags, :terms)

# each TermStruct represents a row in the master taxonomy
TermStruct = Struct.new(:first_level, :second_level, :third_level, :level_hierarchy, :name)

# class for parsing, validating, and querying the master taxonomy document
class MasterTaxonomy

  # parse the master taxonomy document
  def initialize(xlsx_path = nil)
  
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

    return terms.reverse.uniq
  end
  
  # check that the given component is conforms with the master taxonomy
  def check_component(component)
    valid = true
    
    tag = nil
    
    # see if we can find the component's tag in the taxonomy
    tags = component.tags
    if tags.empty?
      puts "Component does not have any tags"
      valid = false
    elsif tags.size > 1
      puts "Component has multiple tags"
      valid = false
    else
      tag = @tag_hash[tags[0].descriptor]
      if not tag
        puts "Cannot find #{tags[0].descriptor} in the master taxonomy"
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
        puts "Cannot find term for #{attribute.name} in #{tag.level_hierarchy}"
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
    root_terms << TermStruct.new("", "", "", "", "OpenStudio Type")
    root_tag = TagStruct.new("", "root", nil, [], root_terms)
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
    
  end
  
  def validate_terms_header(terms_worksheet)
    header_error = false
    
    first_level      = terms_worksheet.Range("A2").Value
    second_level     = terms_worksheet.Range("B2").Value
    third_level      = terms_worksheet.Range("C2").Value
    level_hierarchy  = terms_worksheet.Range("D2").Value
    name             = terms_worksheet.Range("E2").Value
    
    header_error = true if not first_level == "First Level"
    header_error = true if not second_level == "Second Level"
    header_error = true if not third_level == "Third Level"
    header_error = true if not level_hierarchy == "Level Hierarchy"
    header_error = true if not name  == "Term"
    
    return header_error
  end
  
  def parse_term(terms_worksheet, row)
 
    term = TermStruct.new
    term.first_level      = terms_worksheet.Range("A#{row}").Value
    term.second_level     = terms_worksheet.Range("B#{row}").Value
    term.third_level      = terms_worksheet.Range("C#{row}").Value
    term.level_hierarchy  = terms_worksheet.Range("D#{row}").Value
    term.name             = terms_worksheet.Range("E#{row}").Value
    
    # trigger to quit parsing the xcel doc
    if term.first_level.nil? or term.first_level.empty?
      return nil
    end
    
    return term
  end
  
  def add_term(term)
  
    tag = @tag_hash[term.level_hierarchy]
    if tag.nil?
      tag = create_tag(term.level_hierarchy)
    end
    
    if term.name.nil? or term.name.empty?
      # this row is really about the tag
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
    parts = level_hierarchy.split('.')
    
    name = parts[-1]
    parent_level = parts[0..-2].join('.')
    
    parent_tag = @tag_hash[parent_level]
    if parent_tag.nil?
      parent_tag = create_tag(parent_level)
    end
    
    child_tags = []
    terms = []
    tag = TagStruct.new(level_hierarchy, name, parent_tag, child_tags, terms)
    
    parent_tag.child_tags << tag
    
    @tag_hash[level_hierarchy] = tag
    
    return tag
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
    
    # todo: check description, data type, enumerations, units, source, author
    
    return valid
  end
  
  # write a tag to xml
  def write_tag_to_xml(tag, xml)
    xml.tag(:name => "#{tag.name}") {
      #xml.terms {
        #terms = tag.terms.sort {|x, y| x.name <=> y.name} # only direct terms
        terms = get_terms(tag) # all terms, ordered by inheritence
        terms.each do |term|
          xml.term(:name => "#{term.name}")
        end
      #}
      #xml.tags {
        child_tags = tag.child_tags.sort {|x, y| x.name <=> y.name}
        child_tags.each do |child_tag|
          write_tag_to_xml(child_tag, xml)
        end
      #}
    }
  end
  
end

end # module BCL


