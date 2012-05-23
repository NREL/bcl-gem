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
require 'openstudio'
require 'fileutils'
require 'bcl'

require 'test/unit'
  

class MakeComponent_Test < Test::Unit::TestCase

  def test_attribute_only_component
    component_dir = File.dirname(__FILE__) + "/output/attribute_only_component"
    component_name = "test_component"
    
    component = BCL::Component.new(component_dir)
    component.name = component_name
    component.description = "A test component"
    component.fidelity_level = "0"
    component.source_manufacturer = "No one"
    component.source_url = "/dev/null/"
    
    component.add_provenance("author", "datetime", "comment")
    component.add_tag("testing")
    component.add_attribute("is_testing", true, "")
    component.add_attribute("size", 1.0, "ft")
    component.add_attribute("roughness", "very", "")
    puts "hello1"
    puts component.resolve_path 
    puts component_dir + "/" + component_name
    assert(component.resolve_path == component_dir + "/" + component_name)
    puts "hello2"
    FileUtils.rm_rf(component_dir) if File.exists?(component_dir) and File.directory?(component_dir)
    assert((not File.exists?(component_dir)))
    puts "hello3"
    component.save_tar_gz
    puts "hello4"
    assert(File.exists?(component_dir))
    assert(File.exists?(component_dir + "/" + component_name + "/component.xml"))
    assert(File.exists?(component_dir + "/" + component_name + "/" + component_name + ".tar.gz"))
    puts "hello5"
  end
  
  def test_osm_and_osc_component
    component_dir = File.dirname(__FILE__) + "/output/osm_and_osc_component"
    component_name = "test_component"
    
    component = BCL::Component.new(component_dir)
    component.name = component_name
    component.description = "A test component"
    component.fidelity_level = "0"
    component.source_manufacturer = "No one"
    component.source_url = "/dev/null/"
    
    component.add_provenance("author", "datetime", "comment")
    component.add_tag("testing")
    component.add_attribute("is_testing", true, "")
    component.add_attribute("size", 1.0, "ft")
    component.add_attribute("roughness", "very", "")
    
    assert(component.resolve_path == component_dir + "/" + component_name)
    
    FileUtils.rm_rf(component_dir) if File.exists?(component_dir) and File.directory?(component_dir)
    assert((not File.exists?(component_dir)))
    
    FileUtils.mkdir(component_dir)
    FileUtils.mkdir(component_dir + "/" + component_name)
    assert(File.exists?(component_dir))
    assert(File.exists?(component_dir + "/" + component_name))
    
    # make a model
    osm = OpenStudio::Model::Model.new
    version = osm.getVersion
    version.versionIdentifier
    construction = OpenStudio::Model::Construction.new(osm)
    osm.save(OpenStudio::Path.new(component_dir + "/" + component_name + "/component.osm"))
    component.add_file("OpenStudio", version.versionIdentifier, 
                        component_dir + "/" + component_name + "/component.osm", 
                       "component.osm", "osm")
    
    # make a component
    osc = construction.createComponent
    osc.save(OpenStudio::Path.new(component_dir + "/" + component_name + "/component.osc"))
    component.add_file("OpenStudio", version.versionIdentifier, 
                        component_dir + "/" + component_name + "/component.osc", 
                       "component.osc", "osc")
    
    component.save_tar_gz(false)
    
    assert(File.exists?(component_dir + "/" + component_name + "/component.xml"))
    assert(File.exists?(component_dir + "/" + component_name + "/" + component_name + ".tar.gz"))
  end

  def test_gather_components
    component_dir = File.dirname(__FILE__) + "/output/gather_components"
    
    FileUtils.rm_rf(component_dir) if File.exists?(component_dir) and File.directory?(component_dir)
    assert((not File.exists?(component_dir)))
        
    for i in 0..10 do 
    
      component_name = "test_component_#{i}"
    
      component = BCL::Component.new(component_dir)
      component.name = component_name
      component.description = "A test component"
      component.fidelity_level = "0"
      component.source_manufacturer = "No one"
      component.source_url = "/dev/null/"
      
      component.save_tar_gz
    end
    
    assert(File.exists?(component_dir))
    
    File.delete(component_dir + "/gather/components.tar.gz") if File.exists?(component_dir + "/gather/components.tar.gz")
    assert((not File.exists?(component_dir + "/gather/components.tar.gz")))
    
    BCL.gather_components(component_dir)

    assert(File.exists?(component_dir + "/gather/components.tar.gz"))
    
  end
  
end
