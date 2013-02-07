require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/*.rb']
  t.verbose = true
end

desc "Run tests"
task :default => :test

desc "Build gem"
task :build do
  `gem build bcl.gemspec`
  `gem uninstall bcl`
  `gem install bcl`
end
