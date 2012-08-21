Gem::Specification.new do |s|
  s.name = "bcl"
  s.version = "0.1.4"
  s.date = '2012-08-16'
  s.summary = "Classes for creating component XML files for the BCL"
  s.description = "Classes for creating component XML files for the BCL"
  s.authors = ["Dan Macumber","Nicholas Long","Andrew Parker"]
  s.email = "Daniel.Macumber@nrel.gov"
  s.files = ["lib/bcl.rb", 
             "lib/bcl/ComponentSpreadsheet.rb", 
             "lib/bcl/ComponentXml.rb",
             "lib/bcl/GatherComponents.rb",
             "lib/bcl/TarBall.rb",
			 "lib/bcl/MasterTaxonomy.rb",
			 "lib/bcl/MongoToComponent.rb"]
  s.homepage = 'http://bcl.nrel.gov'
  s.add_runtime_dependency("uuid")
  s.add_runtime_dependency("builder")
  s.add_runtime_dependency("zliby")
  s.add_runtime_dependency("archive-tar-minitar")
end