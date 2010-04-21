require 'rake'
Gem::Specification.new do |s|
  s.name     = 'simple_mapper'
  s.version  = '0.0.1'
  s.email    = 'ethan@endpoint.com'
  s.author   = 'Ethan Rowe'
  s.date     = '2010-04-21'
  s.homepage = 'http://github.com/csinitiative/simplemapper'

  s.platform = Gem::Platform::RUBY

  s.description = %q{Provides functionality for building classes that map to/from simple nested data structures of the sort one typically sees with Thrift.}
  s.summary     = %q{Build your classes with this module.  Then you can map from a simple JSON-like structure to instances of your class, and vice versa.  With type conversion, attribute state tracking, etc.}

  s.add_dependency('rake')
  s.add_dependency('shoulda')
  s.add_dependency('mocha')

  s.files = FileList['*.rb', '*.rdoc', 'lib/**/*.rb', 'test/**/*.rb'].to_a
  s.require_path = 'lib'
  s.has_rdoc = true

  s.test_files = Dir['test/**/*_test.rb']
end
