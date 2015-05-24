$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'kitchen/miasma/version'

Gem::Specification.new do |s|
  s.name          = 'kitchen-miasma'
  s.version       = Kitchen::Driver::MIASMA_VERSION
  s.authors       = ['Cameron Johnston']
  s.email         = ['cameron@rootdown.net']
  s.homepage      = ''
  s.add_dependency('test-kitchen', '~> 1.4')
  s.add_dependency('miasma', '~> 0.2')
  s.add_dependency('retryable', '~> 2.0')
  # Include development dependencies for running tests
  s.add_development_dependency 'pry'

  s.summary       = 'Provision Test Kitchen instances using miasma.'
  candidates = Dir.glob('{lib}/**/*') +  ['README.md', 'LICENSE', 'kitchen-miasma.gemspec']
  s.files = candidates.sort
  s.platform      = Gem::Platform::RUBY
  s.require_paths = ['lib']
  s.rubyforge_project = '[none]'
  s.description = 'Provision Test Kitchen instances using miasma.'
end
