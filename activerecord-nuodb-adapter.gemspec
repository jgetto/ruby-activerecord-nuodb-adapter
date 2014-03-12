# -*- encoding: utf-8 -*-
require File.expand_path('../lib/active_record/connection_adapters/nuodb/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name = 'activerecord-nuodb-adapter'
  gem.version = ActiveRecord::ConnectionAdapters::NuoDB::VERSION
  gem.authors = ['Robert Buck']
  gem.email = %w(support@nuodb.com)
  gem.description = %q{An adapter for ActiveRecord and AREL to support the NuoDB distributed database backend.}
  gem.summary = %q{ActiveRecord adapter with AREL support for NuoDB.}
  gem.homepage = 'http://nuodb.github.com/ruby-activerecord-nuodb-adapter/'
  gem.license = 'BSD'

  gem.rdoc_options = %w(--charset=UTF-8)

  gem.add_dependency('activerecord', '~> 3.2.11')
  gem.add_development_dependency('rake', '~> 10.0.3')
  gem.add_development_dependency('rdoc', '~> 3.10')
  gem.add_dependency('nuodb', '~> 2.0.3')


  gem.files = `git ls-files`.split($\)
  gem.test_files = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = %w(lib)
end
