######################################################################
#  Copyright (c) 2008-2013, Alliance for Sustainable Energy.
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

# Provides programmatic access to the component.xsd schema needed for
# generating the component information that will be uploaded to 
# the Building Component Library.

require 'rubygems'

require 'pathname'
require 'csv'
require 'builder'  #gem install builder (creates xml files)
require 'uuid' # gem install uuid
require 'fileutils'

require 'bcl/TarBall'

module BCL

SCHEMA_LOCATION = "component.xsd"

ProvStruct = Struct.new(:author, :datetime, :comment)
TagsStruct = Struct.new(:descriptor)
AttrStruct = Struct.new(:name, :value, :datatype, :units)
FileStruct = Struct.new(:version_software_program, :version_id, :fqp_file, :filename, :filetype)
#cost_type is an enumeration (not enforced) of installation, material, operations and maintenance,
#variable operations and maintenance, salvage
CostStruct = Struct.new(:cost_name, :cost_type, :category, :value, :interval, 
			 :interval_units, :year, :location, :units, :currency, :source,
			 :reference_component_name, :reference_component_id)
ObjectStruct = Struct.new(:obj_type, :obj_instance)
			 
class Component
  attr_accessor :name  
  attr_accessor :uid
  attr_accessor :comp_version_id
  attr_accessor :description
  attr_accessor :comment
  attr_accessor :fidelity_level
  attr_accessor :source_manufacturer
  attr_accessor :source_model
  attr_accessor :source_serial_no
  attr_accessor :source_year
  attr_accessor :source_url
  attr_accessor :tags
  attr_accessor :provenance
  attr_accessor :attributes
  attr_accessor :files
  attr_accessor :costs
  attr_accessor :objects
  
  public 
  
  #the save path is where the component will be saved
  def initialize(save_path)
    @name = ""  #this is also a unique identifier to the component... 
    @uid = UUID.new.generate
    @comp_version_id = UUID.new.generate
    @description = ""
    @comment = ""
    @fidelity_level = 0 #restricted to level_1 to level_5 
    @source_manufacturer = ""
    @source_model = ""
    @source_serial_no = ""
    @source_year = ""
    @source_url = ""
    
    #these items have multiple instances
    @provenance = []
    @tags = []
    @attributes = []
    @files = []
    @costs = []
    @objects = [] #container for saving the idf/osm snippets
    
    @path = save_path
    
    #puts "[ComponentXml] " + @path
    #need to hit a webservice to validate which tags and attributes are 
    #available (including units?)
    
    #todo: validate against master taxonomy
  end
  
  def open_component(filename)
    read_component_xml(filename)
  end
  
  # savefile, save the component xml along with
  # the files that have been added to the object
  def save_tar_gz(delete_files = true)
    current_d = Dir.pwd
    paths = []
    
    save_component_xml
   
    paths << "./component.xml"
    
    #copy over the files to the directory
    @files.each do |file|  
      src_path = Pathname.new(file.fqp_file)
      dest_path = Pathname.new("#{resolve_path}/#{file.filename}")
      if File.exists?(src_path)
        if src_path == dest_path
          #do nothing, file is already where it needs to be
        else
          #move the file where it needs to go
          FileUtils.cp(src_path, dest_path)      
        end
      else
        puts "#{src_path} -> File does not exist"
      end
      paths << "./#{file.filename}"
    end
    
    #take all the files and tar.gz them -- name the file the same as
    #the directory
    
    Dir.chdir("#{resolve_path}")
    destination = "#{@name.gsub(" ","_").gsub("/","_").gsub("-","_").gsub("___","_").gsub("__","_").gsub("in.","in").gsub(",","").strip}.tar.gz"
    
    File.delete(destination) if File.exists?(destination)
    
    BCL.tarball(destination, paths)
      
    Dir.chdir(current_d)

    if (delete_files)
      @files.each do |file|
        if File.exists?(File.dirname(file.fqp_file))
          puts "[ComponentXml] Deleting: #{File.dirname(file.fqp_file)}"
          FileUtils.rm_rf(File.dirname(file.fqp_file)) 
        end
      end
    end
    
    #puts "[ComponentXml] " + Dir.pwd
  end
  
  def add_provenance(author, datetime, comment)
    prov = ProvStruct.new
    prov.author = author
    prov.datetime = datetime
    prov.comment = comment
    
    @provenance << prov
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
  
  def add_file(version_sp, version_id, fqp_file, filename, filetype)
    fs = FileStruct.new
    fs.version_software_program = version_sp
    fs.version_id = version_id
    fs.fqp_file = fqp_file
    fs.filename = filename
    fs.filetype = filetype
    
    @files << fs
  end
  

  def add_cost(cost_name, cost_type, category, value, units, interval, interval_units, year, location, currency, 
  	       source, reference_component_name, reference_component_id)
    cs = CostStruct.new
    cs.cost_name = cost_name
    cs.cost_type = cost_type
    cs.category = category
    cs.value = value
    cs.interval = interval
    cs.interval_units = interval_units
    cs.year = year
    cs.location = location
    cs.units = units
    cs.currency = currency
    cs.source = source
    cs.reference_component_name = reference_component_name
    cs.reference_component_id = reference_component_id
    
    @costs << cs
  end
  
  def add_object(object_type, object_instance)
    ob = ObjectStruct.new
    ob.obj_type = object_type
    ob.obj_instance = object_instance
    
    @objects << ob
  end
  
  def resolve_path
    FileUtils.mkdir_p(@path) unless File.directory?(@path)
    new_path = "#{@path}/#{name.gsub(" ","_").gsub("/","_").gsub("-","_").gsub("___","_").gsub("__","_").gsub("in.","in").gsub(",","").strip}"
    FileUtils.mkdir_p(new_path) unless File.directory?(new_path)
    result = new_path
  end
  
  def osm_resolve_path
    FileUtils.mkdir_p(@path) unless File.directory?(@path)
    new_path = "#{@path}/osm_#{name.gsub(" ","_").gsub("/","_").gsub("-","_").gsub("___","_").gsub("__","_").gsub("in.","in").gsub(",","").strip}"
    FileUtils.mkdir_p(new_path) unless File.directory?(new_path)
    result = new_path
  end
  
  def osc_resolve_path
    FileUtils.mkdir_p(@path) unless File.directory?(@path)
    new_path = "#{@path}/osc_#{name.gsub(" ","_").gsub("/","_").gsub("-","_").gsub("___","_").gsub("__","_").gsub("in.","in").gsub(",","").strip}"
    FileUtils.mkdir_p(new_path) unless File.directory?(new_path)
    result = new_path
  end
  
  def resolve_component_path(component_type)
    FileUtils.mkdir_p(@path) unless File.directory?(@path)
    new_path = @path + '/OpenStudio'
    FileUtils.mkdir_p(new_path) unless File.directory?(new_path)
    new_path = new_path + "/#{component_type}"
    FileUtils.mkdir_p(new_path) unless File.directory?(new_path)
    return new_path
  end
  
  def tmp_resolve_path
    FileUtils.mkdir_p(@path) unless File.directory?(@path)
    new_path = "#{@path}/tmp_#{name.gsub(" ","_").gsub("/","_").gsub("-","_").gsub("___","_").gsub("__","_").gsub("in.","in").gsub(",","").strip}"
    FileUtils.mkdir_p(new_path) unless File.directory?(new_path)
    result = new_path
  end
  
  
  def create_os_component(osobj)
    osobj.getCostLineItems.each do |os|
      @costs.each do |cost|
        #figure out costs for constructions
        os.setMaterialCost(cost.value.to_f) if cost.category == "material"
        if cost.category == "installation"
          os.setInstallationCost(cost.value.to_f)
          os.setExpectedLife(cost.interval.to_i)
        end
        os.setFixedOM(cost.value.to_f) if cost.category == "operations and maintenance"
        os.setVariableOM(cost.value.to_f) if cost.category == "variable operations and maintenance"
        os.setSalvageCost(cost.value.to_f) if cost.category == "salvage"
      end
    end
    newcomp = osobj.createComponent
    
    cd = newcomp.componentData
    cd.setDescription(@description)
    cd.setFidelityLevel(@fidelity_level)
    
    at = newcomp.componentData.componentDataAttributes
    @attributes.each do |attrib|
      if (attrib.value.to_s != "") and (attrib.name.to_s != "")
        if attrib.units != ""
          at.addAttribute(tc(attrib.name), attrib.value, attrib.units)
        else
          at.addAttribute(tc(attrib.name), attrib.value)
        end
      end
    end
    
    tg = newcomp.componentData.componentDataTags
    comp_tag = ""
    @tags.each do |tag|
      tg.addTag(tc(tag.descriptor))
      if (tag.descriptor != "energyplus") and (tag.descriptor != "construction")
        #create a map of component tags to directories
        comp_tag = tag.descriptor
        if comp_tag == "interior wall"
          comp_tag = "interiorwalls"
        elsif comp_tag == "exterior wall"
          comp_tag = "exteriorwalls"
        elsif comp_tag == "exterior slab"
          comp_tag = "exteriorslabs"
        elsif comp_tag == "exposed floor"
          comp_tag = "exposedfloors"
        elsif comp_tag == "attic floor"
          comp_tag = "atticfloors"     
        elsif comp_tag == "roof"
          comp_tag = "roofs"
        elsif comp_tag == "door"
          comp_tag = "doors"
        elsif comp_tag == "skylight"
          comp_tag = "skylights"
        elsif comp_tag == "window"
          comp_tag = "windows"
        end
        puts comp_tag
      end
    end
    
    return newcomp
  end
  
  def save_component_xml(dir_path = resolve_path)
    xmlfile = File.new(dir_path + '/component.xml', 'w')
    comp_xml = Builder::XmlMarkup.new(:target => xmlfile, :indent=>2)

    #setup the xml file
    comp_xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
    comp_xml.component("xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance", 
    		       "xsi:noNamespaceSchemaLocation"=>"#{SCHEMA_LOCATION}") {
      comp_xml.name @name
      comp_xml.uid @uid
      comp_xml.version_id @comp_version_id
      comp_xml.description @description if @description != "" 
      comp_xml.comment @comment if @comment != ""
      comp_xml.fidelity_level @fidelity_level
        
      comp_xml.provenances {
        @provenance.each do |prov|
          comp_xml.provenance {
            comp_xml.author prov.author
            comp_xml.datetime prov.datetime
            comp_xml.comment prov.comment
          }
        end
      }
      
      comp_xml.tags {
        @tags.each do |tag|
          comp_xml.tag tag.descriptor
        end
      }
      
      comp_xml.attributes {
        @attributes.each do |attrib|
          if (attrib.value.to_s != "") and (attrib.name.to_s != "") then
            comp_xml.attribute {
              comp_xml.name attrib.name
              comp_xml.value attrib.value
              comp_xml.datatype attrib.datatype
              comp_xml.units attrib.units if attrib.units != ""
            }
          end
        end
      }
      
      comp_xml.source {
        comp_xml.manufacturer @source_manufacturer if @source_manufacturer != ""
        comp_xml.model @source_model if @source_model != ""
        comp_xml.serial_no @source_serial_no if @source_serial_no != ""
        comp_xml.year @source_year if @source_year != ""
        comp_xml.url @source_url if @source_url != ""
      }
      
      if not @files.nil?
        comp_xml.files {
          @files.each do |file|
            comp_xml.file {
              comp_xml.version {
              comp_xml.software_program file.version_software_program
              comp_xml.identifier file.version_id
            }
	  
            comp_xml.filename file.filename
            comp_xml.filetype file.filetype
	        }
        end
        }
      end
      
      #check if we should write out costs, don't write if all values are 0 or nil
      #DLM: schema always expects costs
      write_costs = true
      #if not @costs.nil?
      #  @costs.each do |cost|
      #    if (cost.value.nil?) && (not cost.value == 0)
      #      write_costs = true
      #      break
      #    end
      #  end
      #end
      
      if write_costs
        comp_xml.costs {
          @costs.each do |cost|
            comp_xml.cost {
              comp_xml.instance_name cost.cost_name
              comp_xml.cost_type cost.cost_type
              comp_xml.category cost.category
              comp_xml.value cost.value
              comp_xml.units cost.units if cost.units != ""
              comp_xml.interval cost.interval if cost.interval != ""
              comp_xml.interval_units cost.interval_units if cost.interval_units != ""
              comp_xml.year cost.year if cost.year != ""
              comp_xml.currency cost.currency if cost.currency != ""
              comp_xml.source cost.source if cost.source != ""
              comp_xml.reference_component_name cost.reference_component_name if cost.reference_component_name != ""
              comp_xml.reference_component_id cost.reference_component_id if cost.reference_component_id != ""
            }
          end
        }
      end
      
    }
    
    xmlfile.close
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

  #return the title case of the string
  def tc(input)
    val = input.gsub(/\b\w/){$&.upcase}
    if val.downcase == "energyplus"
      val = "EnergyPlus"
    end
    return val
  end

  private

  def get_datatype(input_value)
    dt = 'undefined'

    # simple method to test if the input_value is a string, float, or integer.
    # First convert the value back to a string for testing (in case it was passed as a float/integer)
    test = input_value.to_s
    input_value = test.match('\.').nil? ? Integer(test) : Float(test) rescue test.to_s

    if input_value.is_a?(Fixnum) || input_value.is_a?(Bignum)
      dt = "int"
    elsif input_value.is_a?(Float)
      dt = "float"
    else
      dt = "string"
    end

    dt
  end
  
end

end # module BCL