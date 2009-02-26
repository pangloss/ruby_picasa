require 'objectify_xml'
require 'objectify_xml/atom'
require 'cgi'
require 'net/http'
require 'net/https'
require File.join(File.dirname(__FILE__), 'ruby_picasa/types')

module RubyPicasa
  VERSION = '0.1.0'

  class PicasaError < StandardError
  end

  class PicasaTokenError < PicasaError
  end
end

class Picasa
  include RubyPicasa

  class << self
    # The user must be redirected to this address to authorize the application
    # to access their Picasa account. The token_from_request and
    # authorize_request methods can be used to handle the resulting redirect
    # from Picasa.
    def authorization_url(return_to_url, request_session = true, secure = false)
      session = request_session ? '1' : '0'
      secure = secure ? '1' : '0'
      return_to_url = CGI.escape(return_to_url)
      url = 'http://www.google.com/accounts/AuthSubRequest'
      "#{ url }?scope=http%3A%2F%2Fpicasaweb.google.com%2Fdata%2F&session=#{ session }&secure=#{ secure }&next=#{ return_to_url }"
    end

    # Takes a Rails request object and extracts the token from it. This would
    # happen in the action that is pointed to by the return_to_url argument
    # when the authorization_url is created.
    def token_from_request(request)
      if token = request.params['token']
        return token
      else
        raise PicasaTokenError, 'No Picasa authorization token was found.'
      end
    end

    # Takes a Rails request object as in token_from_request, then makes the
    # token authorization request to produce the permanent token. This will
    # only work if request_session was true when you created the
    # authorization_url.
    def authorize_request(request)
      p = Picasa.new(token_from_request(request))
      p.authorize_token!
      p
    end

    def host
      'picasaweb.google.com'
    end

    def is_url?(path)
      path.to_s =~ %r{\Ahttps?://}
    end

    # For more on possible options and their meanings, see: 
    # http://code.google.com/apis/picasaweb/reference.html
    #
    # The following values are valid for the thumbsize and imgmax query
    # parameters and are embeddable on a webpage. These images are available as
    # both cropped(c) and uncropped(u) sizes by appending c or u to the size.
    # As an example, to retrieve a 72 pixel image that is cropped, you would
    # specify 72c, while to retrieve the uncropped image, you would specify 72u
    # for the thumbsize or imgmax query parameter values.
    #
    # 32, 48, 64, 72, 144, 160
    #
    # The following values are valid for the thumbsize and imgmax query
    # parameters and are embeddable on a webpage. These images are available as
    # only uncropped(u) sizes by appending u to the size or just passing the
    # size value without appending anything. 
    #
    # 200, 288, 320, 400, 512, 576, 640, 720, 800
    #
    # The following values are valid for the thumbsize and imgmax query
    # parameters and are not embeddable on a webpage. These image sizes are
    # only available in uncropped format and are accessed using only the size
    # (no u is appended to the size).
    #
    # 912, 1024, 1152, 1280, 1440, 1600
    # 
    def path(args = {})
      path, options = parse_url(args)
      if path.nil?
        path = ["/data/feed/api"]
        if args[:user_id] == 'all'
          path += ["all"]
        else
          path += ["user", CGI.escape(args[:user_id] || 'default')]
        end
        path += ['albumid', CGI.escape(args[:album_id])] if args[:album_id]
        path = path.join('/')
      end
      options['kind'] = 'photo' if args[:recent_photos] or args[:album_id]
      [:max_results, :start_index, :tag, :q, :kind,
       :access, :thumbsize, :imgmax, :bbox, :l].each do |arg|
        options[arg.to_s.dasherize] = args[arg] if args[arg]
      end
      if options.empty?
        path
      else
        [path, options.map { |k, v| [k.to_s, CGI.escape(v.to_s)].join('=') }.join('&')].join('?')
      end
    end

    private

    def parse_url(args)
      url = args[:url]
      url ||= args[:user_id] if is_url?(args[:user_id]) 
      url ||= args[:album_id] if is_url?(args[:album_id])
      if url
        uri = URI.parse(url)
        path = uri.path
        options = {}
        if uri.query
          uri.query.split('&').each do |query|
            k, v = query.split('=')
            options[k] = CGI.unescape(v)
          end
        end
        [path, options]
      else
        [nil, {}]
      end
    end
  end

  attr_reader :token

  def initialize(token)
    @token = token
    @request_cache = {}
  end

  def authorize_token!
    http = Net::HTTP.new("www.google.com", 443)
    http.use_ssl = true
    response = http.get('/accounts/accounts/AuthSubSessionToken', auth_header)
    token = response.body.scan(/Token=(.*)/).flatten.compact.first
    if token
      @token = token
    else
      raise RubyPicasa::PicasaTokenError, 'The request to upgrade to a session token failed.'
    end
    @token
  end

  def user(user_id_or_url = 'default', options = {})
    get(options.merge(:user_id => user_id_or_url))
  end

  def album(album_id_or_url, options = {})
    get(options.merge(:album_id => album_id_or_url))
  end

  # This request does not require authentication.
  def search(q, options = {})
    h = {}
    h[:max_results] = 10
    h[:user_id] = 'all'
    h[:kind] = 'photo'
    # merge options over h, but merge q over options
    get(h.merge(options).merge(:q => q))
  end

  def get_url(url, options = {})
    get(options.merge(:url => url))
  end

  def recent_photos(user_id_or_url = 'default', options = {})
    if user_id_or_url.is_a?(Hash)
      options = user_id_or_url
      user_id_or_url = 'default'
    end
    h = {}
    h[:user_id] = user_id_or_url
    h[:recent_photos] = true
    get(options.merge(h))
  end

  def album_by_title(title, options = {})
    if a = user.albums.find { |a| title === a.title }
      a.load options
    end
  end

  def xml(options = {})
    http = Net::HTTP.new(Picasa.host, 80)
    path = Picasa.path(options)
    response = http.get(path, auth_header)
    if response.code =~ /20[01]/
      response.body
    end
  end

  def get(options = {})
    with_cache(options) do |xml|
      class_from_xml(xml)
    end
  end

  private

  def auth_header
    if token
      { "Authorization" => %{AuthSub token="#{ token }"} }
    else
      {}
    end
  end

  def with_cache(options)
    path = Picasa.path(options)
    @request_cache.delete(path) if options[:reload]
    xml = nil
    if @request_cache.has_key? path
      xml = @request_cache[path]
    else
      xml = @request_cache[path] = xml(options)
    end
    if xml
      yield xml
    end
  end

  def xml_data(xml)
    if xml = Objectify::Xml.first_element(xml)
      # There is something wrong with Nokogiri xpath/css search with
      # namespaces. If you are searching a document that has namespaces,
      # it's impossible to match any elements in the root xmlns namespace.
      # Matching just on attributes works though.
      feed, entry = xml.search('//*[@term][@scheme]', xml.namespaces)
      feed_scheme = feed['term'] if feed
      entry_scheme = entry['term'] if entry
      [xml, feed_scheme, entry_scheme]
    end
  end

  def class_from_xml(xml)
    xml, feed_scheme, entry_scheme = xml_data(xml)
    if xml
      r = case feed_scheme
      when /#user$/
        case entry_scheme
        when /#album$/
          User.new(xml, self)
        when /#photo$/
          RecentPhotos.new(xml, self)
        end
      when /#album$/
        case entry_scheme
        when nil, /#photo$/
          Album.new(xml, self)
        end
      when /#photo$/
        case entry_scheme
        when /#photo$/
          Search.new(xml, self)
        when nil
          Photo.new(xml, self)
        end
      end
      if r
        r.session = self
        r
      else
        raise PicasaError, "Unknown feed type\n feed:  #{ feed_scheme }\n entry: #{ entry_scheme }"
      end
    end
  end
end
