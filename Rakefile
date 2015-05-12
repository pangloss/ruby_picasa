# -*- ruby -*-

require 'rubygems'
require './lib/ruby_picasa.rb'
require 'spec/rake/spectask'

desc "Run all specifications"
Spec::Rake::SpecTask.new(:spec) do |t|
  t.libs = ['lib', 'spec']
  t.spec_opts = ['--colour', '--format', 'specdoc']
end

task :default => [:spec]

begin
  require "jeweler"
  Jeweler::Tasks.new do |gem|

    gem.name = "ruby-picasa"
    gem.summary = "Provides a super easy to use object layer for authenticating and accessing Picasa through their API."
    gem.description = "Provides a super easy to use object layer for authenticating and accessing Picasa through their API."
    gem.email = "fourcade.m+ruby_picasa@gmail.com"
    gem.homepage = "http://github.com/mfo/ruby_picasa"
    gem.authors = [
      'pangloss',
      'darrick@innatesoftware.com',
      'fjg@happycoders.org',
      'fourcade.m+ruby_picasa@gmail.com'
    ]

    gem.add_dependency "objectify-xml", ">=0.2.3"
    gem.add_dependency "signet", ">= 0.6.0"
    gem.add_dependency "activesupport", ">= 3.2"

    gem.files.include %w(README.txt History.txt lib/**/** spec/**/**)
  end
rescue
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

# vim: syntax=Ruby
