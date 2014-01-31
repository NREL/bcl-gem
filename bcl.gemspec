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
  s.description = "This gem contains helper methods for generating the Component XML file needed to upload files to the Building Component Library. It also contains the classes needed for logging in via the api and uploading generating components"
  s.license = "LGPL"

  s.add_runtime_dependency("uuid")
  s.add_runtime_dependency("builder")
  s.add_runtime_dependency("zliby")
  s.add_runtime_dependency("archive-tar-minitar")
  s.add_runtime_dependency("json_pure")
  s.add_runtime_dependency("rest-client") #todo: remove this in favor of faraday
  s.add_runtime_dependency("libxml-ruby")
  s.add_runtime_dependency("yamler")
  s.add_runtime_dependency("faraday")

  # Support for Ruby 1.8.7 if using OpenStudio Ruby Bindings
  # we can remove these version constraint when we move over to Ruby 2.0)
  s.add_runtime_dependency("rubyzip", "~> 0.9.9")
  s.add_runtime_dependency("mime-types", "~> 1.25.1")
  s.add_runtime_dependency("roo", "~> 1.10.3")
  s.add_runtime_dependency("nokogiri", "~> 1.5.10")


  
  s.files = Dir.glob("lib/**/*")
  s.require_path = "lib"

end


