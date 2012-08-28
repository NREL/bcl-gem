require 'rubygems'
require 'bcl'

dirname = File.dirname(__FILE__)

taxonomy = BCL::MasterTaxonomy.new(dirname + '\..\..\Taxonomy\unified taxonomy.xlsm')
taxonomy.save_as_current_taxonomy()
taxonomy.save_as_current_taxonomy(dirname + '\lib\bcl\current_taxonomy.json')
taxonomy.write_xml(dirname + '\lib\bcl\current_taxonomy.xml')

taxonomy2 = BCL::MasterTaxonomy.new()