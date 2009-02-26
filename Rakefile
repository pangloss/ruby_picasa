# -*- ruby -*-

require 'rubygems'
require 'hoe'
require './lib/ruby_picasa.rb'
require 'spec/rake/spectask'

Hoe.new('ruby_picasa', RubyPicasa::VERSION) do |p|
  p.rubyforge_name = 'ruby-picasa'
  p.developer('pangloss', 'darrick@innatesoftware.com')
  p.extra_deps = 'objectify-xml'
  p.testlib = 'spec'
  p.test_globs = 'spec/**/*_spec.rb'
end

desc "Run all specifications"
Spec::Rake::SpecTask.new(:spec) do |t|
  t.libs = ['lib', 'spec']
  t.spec_opts = ['--colour', '--format', 'specdoc']
end

# vim: syntax=Ruby
