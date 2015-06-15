require 'rubygems'
require File.expand_path(File.join(File.dirname(__FILE__), '../lib/ruby_picasa'))

require 'mocha'
require 'pp'

def open_file(name)
  open(File.join(File.dirname(__FILE__), File.join('sample', name)))
end

RSpec.configure do |config|
  config.mock_framework = :mocha
end
