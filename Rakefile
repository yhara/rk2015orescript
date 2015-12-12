require 'bundler/setup'
require 'opal-rspec'
Opal.append_path("#{__dir__}/opal")
require 'opal/rspec/rake_task'
Opal::RSpec::RakeTask.new(:opal)

task :default do
  sh "racc -o lib/ore_script/parser.rb lib/ore_script/parser.ry"
  sh "rspec"
end
