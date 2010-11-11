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
    gem.email = "fjg@happycoders.org"
    gem.homepage = "http://github.com/fjg/ruby_picasa"
    gem.authors = ['pangloss', 'darrick@innatesoftware.com', 'fjg@happycoders.org']

    gem.add_dependency "objectify-xml", ">=0.2.3"

    gem.files.include %w(README.txt History.txt lib/**/** spec/**/**)
  end
rescue
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

# vim: syntax=Ruby
