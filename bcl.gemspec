lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'bcl/version'

Gem::Specification.new do |s|
  s.name = 'bcl'
  s.version = BCL::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['Daniel Macumber', 'Nicholas Long', 'Andrew Parker', 'Katherine Fleming']
  s.email = 'Nicholas.Long@nrel.gov'
  s.homepage = 'http://bcl.nrel.gov'
  s.summary = 'Classes for creating component XML files for the BCL'
  s.description = 'This gem contains helper methods for generating the Component XML file needed to upload files to the Building Component Library. It also contains the classes needed for logging in via the api and uploading generating components'
  s.license = 'LGPL'

  s.required_ruby_version = '>= 1.9.2'

  # TODO reconcile all these dependencies
  s.add_runtime_dependency('uuid')
  s.add_runtime_dependency('builder')
  s.add_runtime_dependency('zliby')
  s.add_runtime_dependency('archive-tar-minitar')
  s.add_runtime_dependency('multi_json')
  s.add_runtime_dependency('yamler')
  s.add_runtime_dependency('faraday')
  s.add_runtime_dependency('roo')
  s.add_runtime_dependency('nokogiri')
  s.add_runtime_dependency('rubyzip')
  s.add_runtime_dependency('rubyXL')

  s.add_development_dependency('rake', '~> 10.4.2')
  s.add_development_dependency('rspec', '~> 3.0')
  s.add_development_dependency('rubocop', '~> 0.26.1')
  s.add_development_dependency('rubocop-checkstyle_formatter', '~> 0.1.1')
  s.add_development_dependency('ci_reporter', '~> 1.9.1')
  s.add_development_dependency('rspec-legacy_formatters', '~> 1.0.0')

  s.files = Dir.glob('lib/**/*')
  s.require_path = 'lib'

end
