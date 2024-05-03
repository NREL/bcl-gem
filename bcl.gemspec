lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bcl/version'

Gem::Specification.new do |spec|
  spec.name          = 'bcl'
  spec.version       = BCL::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = ['Daniel Macumber', 'Nicholas Long', 'Andrew Parker', 'Katherine Fleming']
  spec.email         = 'Nicholas.Long@nrel.gov'

  spec.homepage      = 'http://bcl.nrel.gov'
  spec.summary       = 'Classes for creating component XML files and manageing measures for the BCL'
  spec.description   = 'This gem contains helper methods for generating the Component XML file needed to upload files to the Building Component Library. It also contains the classes needed for logging in via the api and uploading generating components and measures.'
  spec.license       = 'BSD'
  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/NREL/bcl-gem/issues',
    'changelog_uri' => 'https://github.com/NREL/bcl-gem/blob/develop/CHANGELOG.md',
    'source_code_uri' => "https://github.com/NREL/bcl-gem/tree/v#{spec.version}"
  }

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '~> 3.2.2'

  spec.add_dependency 'builder', '3.2.4'
  spec.add_dependency 'faraday', '~> 1.0.1'
  spec.add_dependency 'minitar', '~> 0.9'

  # Measure tester is not used in this project, but this will force dependencies to match versions
  # requested by OpenStudio. This includes dependencies for running tests/CI
  spec.add_dependency 'openstudio_measure_tester', '~> 0.4.0'
  spec.add_dependency 'rexml', '3.2.5'
  spec.add_dependency 'rubyzip', '~> 2.3.2'
  spec.add_dependency 'spreadsheet', '1.2.9'
  spec.add_dependency 'uuid', '~> 2.3.9'
  spec.add_dependency 'yamler', '0.1.0'
  spec.add_dependency 'zliby', '0.0.5'

  spec.add_development_dependency 'bundler', '2.4.10'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.9'
end
