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

#Mongo Record to Component
require 'rubygems'
require 'bcl/component_xml'

module BCL

class MongoToComponent
	attr_accessor :component
	attr_accessor :error_message
	
   	def initialize(record)
		@component = nil
		@error_message = ""
		
		if record.has_key? "general"
			@component = BCL::Component.new('tmp')
			general = record["general"]

			#add uid/vid
			if record.has_key? "unique_id"
				component.uid = record["unique_id"]
			else
				@error_message = "Invalid Mongo record: no unique_id"
			end
			if record.has_key? "version_id"
				component.comp_version_id = record["version_id"]
			else
				@error_message = "Invalid Mongo record: no version_id"	
			end
			
			#add general info
			if general.has_key? "name"
				component.name = general["name"]
			end
			if general.has_key? "description"
				@component.description = general["description"]
			end
			if general.has_key? "fidelity_level"
				@component.fidelity_level = general["fidelity_level"]
			end
			if general.has_key? "source_manufacturer"
				@component.source_manufacturer = general["source_manufacturer"]
			end
			if general.has_key? "source_url"
				@component.source_url = general["source_url"]
			end

			#add tags
			if general.has_key? "tags"
				tags = general["tags"]
				tags.each do |name,value|
					@component.add_tag(value)
				end
			end
		
			#add attributes
			if general.has_key? "attributes"
				attribute_container = general["attributes"]
				attribute_container.each do |a,attributes|
					#attributes iterator is an array of hashes 
					#NOTE: double check this...could be old messed-up structure?
					attributes.each do |attribute|
						name = ""
						units = ""
						value = ""
						datatype = ""
						if attribute.has_key? "name"
							name = attribute["name"]
						end
						if attribute.has_key? "value"
							value = attribute["value"]
						end
						if attribute.has_key? "units"
							units = attribute["units"]
						end
						@component.add_attribute(name, value, units)
						
						#TODO: eventually find a way to validate the datatype in record with datatype in component
					end
				end
			end
			
			#todo: add provenance
			
		else
			@error_message = "Invalid Mongo record: no 'general' section"
		end
		#set component to NIL if there were errors
		if !@error_message == nil
			@component = nil
		end
	end
	
end

end # module BCL

