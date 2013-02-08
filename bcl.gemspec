lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require "bcl/version"

Gem::Specification.new do |s|
  s.name = "bcl"
  s.version = BCL::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Daniel Macumber","Nicholas Long","Andrew Parker", "Katherine Fleming"]
  s.email = "Nicholas.Long@nrel.gov"
  s.homepage = 'http://bcl.nrel.gov'
  s.summary = "Classes for creating component XML files for the BCL"
  s.description = "Classes for creating component XML files for the BCL"
  s.license = "LGPL"


  s.add_runtime_dependency("uuid")
  s.add_runtime_dependency("builder")
  s.add_runtime_dependency("zliby")
  s.add_runtime_dependency("archive-tar-minitar")
  s.add_runtime_dependency("mongo")

  s.files = Dir.glob("lib/**/*")
  s.require_path = "lib"

end