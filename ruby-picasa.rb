require 'objectify_xml'
require 'objectify_xml/atom'
require 'cgi'
require 'net/http'
require 'net/https'
require 'ruby-picasa/types'

module RubyPicasa
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
      "http://www.google.com/accounts/AuthSubRequest?scope=http%3A%2F%2Fpicasaweb.google.com%2Fdata%2F&session=#{ session }&secure=#{ secure }&next=#{ return_to_url }"
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

    # This request does not require authentication.
    def search(q, start_index = 1, max_results = 10)
      Search.new(q, start_index, max_results)
    end

    def host
      'picasaweb.google.com'
    end

    def is_url?(path)
      path.to_s =~ %r{\Ahttps?://}
    end

    def path(args = {})
      options = {}
      path = []
      url = args[:url]
      url ||= args[:user_id] if is_url?(args[:user_id]) 
      url ||= args[:album_id] if is_url?(args[:album_id])
      if url
        uri = URI.parse(url)
        path << uri.path
        if uri.query
          uri.query.split('&').each do |query|
            k, v = query.split('=')
            options[k] = v
          end
        end
      else
        path = ["/data/feed/api/user", CGI.escape(args[:user_id] || 'default')]
        pp args
        pp args[:album_id]
        path += ['albumid', CGI.escape(args[:album_id])] if args[:album_id]
      end
      if args[:kind]
        options['kind'] = args[:kind]
      else
        options['kind'] = 'photo' if args[:recent_photos] or args[:album_id]
        options['kind'] = 'comment' if args[:comments]
      end
      options['max-results'] = args[:max_results] if args[:max_results]
      options['start-index'] = args[:start_index] if args[:start_index]
      options['tag'] = args[:tag] if args[:tag]
      options['q'] = args[:q] if args[:q] # search string
      path = path.join('/')
      if options.empty?
        path
      else
        [path, options.map { |k, v| [k.to_s, CGI.escape(v.to_s)].join('=') }.join('&')].join('?')
      end
    end
  end

  attr_reader :token

  def initialize(token)
    @token = token
    @request_cache = {}
  end

  def auth_header
    if token
      { "Authorization" => %{AuthSub token="#{ token }"} }
    else
      {}
    end
  end

  def authorize_token!
    http = Net::HTTP.new("www.google.com", 443)
    http.use_ssl = true
    response = http.get('/accounts/accounts/AuthSubSessionToken', auth_header)
    @token = response.body.scan(/Token=(.*)/).first
    if @token.nil?
      raise PicasaTokenError, 'The request to upgrade to a session token failed.'
    end
    @token
  end

  def user(options = {})
    with_cache(options) do
      if xml = xml(options)
        class_from_xml(xml)
      end
    end
  end

  def albums(options = {})
    if u = user(options)
      u.entries
    else
      []
    end
  end

  def album_by_title(title, options = {})
    if a = albums.find { |a| title === a.title }
      a.load options
    end
  end

  # The album contains photos, there is no individual photo request.
  def album(options = {})
    with_cache(options) do
      if xml = xml(options)
        class_from_xml(xml)
      end
    end
  end

  def photos(options = {})
    if a = album(options)
      a.entries
    else
      []
    end
  end

  def xml(options = {})
    http = Net::HTTP.new(Picasa.host, 80)
    path = Picasa.path(options)
    puts path
    response = http.get(path, auth_header)
    if response.code =~ /20[01]/
      response.body
    end
  end

  def from_url(url, options = {})
    with_cache(options.merge(:url => url)) do
      if xml = xml(:url => url)
        class_from_xml(xml)
      end
    end
  end

  private

  def with_cache(options)
    path = Picasa.path(options)
    @request_cache.delete(path) if options[:reload]
    if @request_cache.has_key? path
      @request_cache[path]
    else
      @request_cache[path] = yield
    end
  end

  def class_from_xml(xml)
    r = if xml = Nokogiri::XML.parse(xml)
      # There is something wrong with Nokogiri xpath/css search with
      # namespaces. If you are searching a document that has namespaces,
      # it's impossible to match any elements in the root xmlns namespace.
      # Matching just on attributes works though.
      feed, entry = xml.search('//*[@term][@scheme]', xml.namespaces)
      feed_scheme = feed['term'] if feed
      entry_scheme = entry['term'] if entry
      case feed_scheme
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
        Photo.new(xml, self)
      end
    end
    if r
      r.session = self
      r
    else
      raise "Unknown feed type\n feed:  #{ feed_scheme }\n entry: #{ entry_scheme }"
    end
  end
end
