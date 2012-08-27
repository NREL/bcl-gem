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

#parse through Mongo database to validate BCL records

require 'rubygems'
require 'mongo'  		#gem install mongo, gem install bson_ext
require 'bson'
require 'bcl'

conn_str = nil
db_str = nil
user_str = nil
pwd_str = nil

# get credentials to connect to BCL mongo database and authenticate
if cred_file = ARGV[0]

  File.open(cred_file, 'r') do |file|
    conn_str = file.gets
    db_str = file.gets
    user_str = file.gets
    pwd_str = file.gets
  end
  
  if conn_str.nil? or db_str.nil? or user_str.nil? or pwd_str.nil?
    puts "Invalid credentials file"
    exit
  end
  
else
  puts "Enter Mongo server Hostname or IP: "
  conn_str = gets
  puts "Enter Mongo database: "
  db_str = gets
  puts "Enter Mongo username: "
  user_str = gets
  puts "Enter Mongo password: "
  pwd_str = gets
end

connection = Mongo::Connection.new(conn_str.strip)
db = connection.db(db_str.strip)
auth = db.authenticate(user_str.strip, pwd_str.strip)

#use nrel.component collection
coll = db.collection("nrel.component")

puts "there are #{coll.count} records in this collection"
puts "\n"

#initialize MasterTaxonomy class
taxonomy = BCL::MasterTaxonomy.new

#TEST: find a record in the collection
 coll.find({"general.name" => /#{'ASHRAE'}/}).limit(2).each do |record|

	#convert mongo record to component to do MasterTaxonomy validation
	#TODO:  only do this for published/current nodes
	mongo_to_component = BCL::MongoToComponent.new(record)
	if !mongo_to_component.component.nil?
	  component = mongo_to_component.component
	  puts "component #{component.name}"

	  #validate component
	  valid = taxonomy.check_component(mongo_to_component.component)
	  
		if valid == true
			puts "component is valid"
		else
			puts "component is not valid"
		end
	else
	  puts "error found: #{mongo_to_component.error_message}"
	end	
end