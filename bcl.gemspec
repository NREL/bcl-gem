Gem::Specification.new do |s|
  s.name = "bcl"
  s.version = "0.1.3"
  s.date = '2012-08-01'
  s.summary = "Classes for creating component XML files for the BCL"
  s.description = "Classes for creating component XML files for the BCL"
  s.authors = ["Dan Macumber","Nicholas Long","Andrew Parker"]
  s.email = "Daniel.Macumber@nrel.gov"
  s.files = ["lib/bcl.rb", 
             "lib/bcl/ComponentSpreadsheet.rb", 
             "lib/bcl/ComponentXml.rb",
             "lib/bcl/GatherComponents.rb",
             "lib/bcl/TarBall.rb"]
  s.homepage = 'http://bcl.nrel.gov'
  s.add_runtime_dependency("uuid")
  s.add_runtime_dependency("builder")
  s.add_runtime_dependency("zliby")
  s.add_runtime_dependency("archive-tar-minitar")
end