require File.join(File.dirname(__FILE__), 'spec_helper')

describe Picasa do
  it 'should generate an authorization_url' do
    return_url = 'http://example.com/example?example=ex'
    url = Picasa.authorization_url(return_url)
    url.should include(CGI.escape(return_url))
    url.should match(/session=1/)
  end
end
