require 'objectify_xml'
require 'objectify_xml/atom'
require 'cgi'
require 'ruby-picasa/types'

require 'open-uri'

module RubyPicasa
  def PicasaError < StandardError
  end

  def PicasaTokenError < PicasaError
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
      auth = request.headers['Authorization'] 
      if auth
        token = auth.scan(/AuthSub token="(.*)"/).first
        return token if token
      end
      raise PicasaTokenError, 'No Picasa authorization token was found.'
    end

    # Takes a Rails request object as in token_from_request, then makes the
    # token authorization request to produce the permanent token. This will
    # only work if request_session was true when you created the
    # authorization_url.
    def authorize_request(user_id, request)
      p = Picasa.new(user_id, token_from_request(request))
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

    def path(user_id, args = {})
      path = ["/data/feed/api/user", CGI.escape(user_id)]
      path += ['albumid', CGI.escape(options[:album_id])] if options[:album_id]
      options = {}
      options['kind'] = 'photo' if args[:recent_photos]
      options['kind'] = 'comment' if args[:comments]
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

  attr_reader :token, :user_id

  # can use 'default' to use the currently authorized user's account, but I'm not clear how that would know
  # 
  def initialize(token)
    @user_id = user_id
    @token = token
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
    @token = response['Token']
    if @token.nil?
      raise PicasaTokenError, 'The request to upgrade to a session token failed.'
    end
    @token
  end

  def user(user_id = 'default', options = {})
    if xml = get(user_id, options)
      User.new(xml)
    end
  end

  def albums(*args)
    if u = user(*args)
      u.entries
    else
      []
    end
  end

  # The album contains photos, there is no individual photo request.
  def album(album_id, user_id = 'default', options = {})
    if xml = get(user_id, options.merge(:album_id => album_id))
      Album.new(xml)
    end
  end

  def photos(*args)
    if a = album(*args)
      a.entries
    else
      []
    end
  end

  private

  def get(user_id, args = {})
    http = Net::HTTP.new(Picasa.host, 80)
    response = http.get(Picasa.path(user_id, args), auth_header)
    if response.code =~ /20[01]/
      response.body
    end
  end

end
