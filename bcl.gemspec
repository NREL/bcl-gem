Gem::Specification.new do |s|
  s.name = "bcl"
  s.version = "0.1.2"
  s.date = '2012-07-27'
  s.summary = "Classes for creating component XML files for the BCL"
  s.description = "Classes for creating component XML files for the BCL"
  s.authors = ["Dan Macumber"]
  s.email = ""
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