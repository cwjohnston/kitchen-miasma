#!/usr/bin/env rake

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.pattern = ['spec/**{,/*/**}/*_spec.rb']
  end
rescue LoadError
end
