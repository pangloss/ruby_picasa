require 'active_support/inflector'
require 'google/api_client'
require 'objectify_xml'
require 'objectify_xml/atom'
require 'cgi'
require 'net/http'
require 'net/https'
require 'signet/oauth_2'
require 'signet/oauth_2/client'

require File.join(File.dirname(__FILE__), 'ruby_picasa/types')

module RubyPicasa
  class PicasaError < StandardError
  end

  class PicasaTokenError < PicasaError
  end

  class PicasaTokenRevokedError < PicasaError
  end
end

# == Authorization
#
# RubyPicasa makes authorizing a Rails app easy. It is an Oauth2 classic process
#
# First redirect the user to the authorization url, if the user authorizes your
# application, Picasa will redirect the user back to the url you specify (in
# this case authorize_picasa_url).
#
# Next, pass the Rails request object to the authorize_token method which will
# make the api call to upgrade the token and if successful return an initialized
# Picasa session object ready to use. The token object can be retrieved from the
# token attribute.
#
#   class PicasaController < ApplicationController
#     def request_authorization
#       redirect_to Picasa.authorization_url(authorize_picasa_url)
#     end
#
#     def authorize
#       if Picasa.code_in_request?(request)
#         begin
#           picasa = Picasa.authorize_request(request)
#           current_user.picasa_token = picasa.token
#           current_user.save
#           flash[:notice] = 'Picasa authorization complete'
#           redirect_to picasa_path
#         rescue PicasaTokenError => e
#           #
#           @error = e.message
#           render
#         end
#       end
#     end
#   end
#
class Picasa
  OAUTH_SCOPE = 'https://picasaweb.google.com/data/'

  class << self
    # Use Google::APIClient to setup a valid Signet::OAuth2::Client
    def build_google_oauth2_signet(client_id)
      s = Google::APIClient.new(application_name: 'sharypic', application_version: '1.0.0').authorization

      s.scope = OAUTH_SCOPE
      s.client_id = client_id
      s
    end

    # The user must be redirected to this address to authorize the application
    # to access their Picasa account. The code_from_request and
    # authorize_request methods can be used to handle the resulting redirect
    # from Picasa.
    def authorization_url(client_id, redirect_uri)
      s = build_google_oauth2_signet(client_id)
      s.redirect_uri = redirect_uri

      s.authorization_uri({
       approval_prompt: :force,
       access_type: :offline,
      }).to_s
    end

    # Takes a Rails request object and extracts the token from it. This would
    # happen in the action that is pointed to by the redirect_uri argument
    # when the authorization_url is created.
    def code_from_request(request)
      if code = request.parameters['code']
        return code
      else
        raise RubyPicasa::PicasaTokenError, 'No Picasa authorization code was found.'
      end
    end

    def code_in_request?(request)
      request.parameters['code']
    end

    # Takes a Rails request object as in code_from_request, then makes the
    # token authorization request to produce the permanent token. This will
    # only work if request_session was true when you created the
    # authorization_url.
    def authorize_request(client_id, client_secret, redirect_uri, request)
      s = build_google_oauth2_signet(client_id)
      s.redirect_uri = redirect_uri
      s.client_secret = client_secret
      s.code = code_from_request(request)
      p = Picasa.new(s)
      p.authorize_token!
      p
    end

    # The url to make requests to without the protocol or path.
    def host
      @host ||= 'https://picasaweb.google.com'
    end

    # In the unlikely event that you need to access this api on a different url,
    # you can set it here. It defaults to picasaweb.google.com
    def host=(h)
      @host = h
    end

    # A simple test used to determine if a given resource id is it's full
    # identifier url. This is not intended to be a general purpose method as the
    # test is just a check for the http/https protocol prefix.
    def is_url?(path)
      (path.to_s =~ %r{\Ahttps?://}) != nil
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
      if args[:thumbsize] and not args[:thumbsize].split(/,/).all? { |s| RubyPicasa::Photo::VALID.include?(s) }
        raise RubyPicasa::PicasaError, 'Invalid thumbsize.'
      end
      if args[:imgmax] and not RubyPicasa::Photo::VALID.include?(args[:imgmax])
        raise RubyPicasa::PicasaError, 'Invalid imgmax.'
      end
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

    # Extract the path and a hash of key/value pairs from a given url with
    # optional query string.
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

  # The Signet::OAuth2::Client token currently in use.
  attr_reader :oauth2_signet

  def initialize(signet)
    @oauth2_signet = signet
    @request_cache = {}
  end

  # Takes a OAuth2 signeet and verify if it's still valid
  def valid_oauth_access_token?
    @oauth2_signet.expired?
  end

  # Attempt to upgrade the current OAuth2 signet to a permanent one. This only
  # works if the Picasa session is initialized with a single use token.
  def authorize_token!
    oauth2_signet.fetch_access_token!
  rescue Signet::AuthorizationError => e
    raise RubyPicasa::PicasaTokenError, 'The request to upgrade to a session token failed.'
  end

  # Retrieve a RubyPicasa::User record including all user albums.
  def user(user_id_or_url = nil, options = {})
    options = make_options(:user_id, user_id_or_url, options)
    get(options)
  end

  # Retrieve a RubyPicasa::Album record. If you pass an id or a feed url it will
  # include all photos. If you pass an entry url, it will not include photos.
  def album(album_id_or_url, options = {})
    options = make_options(:album_id, album_id_or_url, options)
    get(options)
  end

  # This request does not require authentication. Returns a RubyPicasa::Search
  # object containing the first 10 matches. You can call #next and #previous to
  # navigate the paginated results on the Search object.
  def search(q, options = {})
    h = {}
    h[:max_results] = 10
    h[:user_id] = 'all'
    h[:kind] = 'photo'
    # merge options over h, but merge q over options
    get(h.merge(options).merge(:q => q))
  end

  # Retrieve a RubyPicasa object determined by the type of xml results returned
  # by Picasa. Any supported type of RubyPicasa resource can be requested with
  # this method.
  def get_url(url, options = {})
    options = make_options(:url, url, options)
    get(options)
  end

  # Retrieve a RubyPicasa::RecentPhotos object, essentially a User object which
  # contains photos instead of albums.
  def recent_photos(user_id_or_url, options = {})
    options = make_options(:user_id, user_id_or_url, options)
    options[:recent_photos] = true
    get(options)
  end

  # Retrieves the user's albums and finds the first one with a matching title.
  # Returns a RubyPicasa::Album object.
  def album_by_title(title, options = {})
    if a = user.albums.find { |a| title === a.title }
      a.load options
    end
  end

  # Returns the raw xml from Picasa. See the Picasa.path method for valid
  # options.
  def xml(options = {})
    host = Picasa.host
    path = Picasa.path(options)
    url = URI("#{host}#{path}")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    req = add_auth_headers(Net::HTTP::Get.new url.path)

    response = http.request(req)
    if response.code =~ /20[01]/
      response.body
    end
  end

  private

  # If the value parameter is a hash, treat it as the options hash, otherwise
  # insert the value into the hash with the key specified.
  #
  # Uses merge to ensure that a new hash object is returned to prevent caller's
  # has from accidentally being modified.
  def make_options(key, value, options)
    if value.is_a? Hash
      {}.merge value
    else
      options ||= {}
      options.merge(key => value)
    end
  end

  # Combines the cached xml request with the class_from_xml factory. See the
  # Picasa.path method for valid options.
  def get(options = {})
    with_cache(options) do |xml|
      class_from_xml(xml)
    end
  end

  # Returns the header data needed to make Google OAuth2 requests.
  def add_auth_headers(req)
    req['GData-Version'] = '2'
    req['Authorization'] = "Bearer #{oauth2_signet.access_token}" if !@oauth2_signet.nil? && !  oauth2_signet.access_token.nil?
    req
  end

  # Caches the raw xml returned from the API. Keyed on request url.
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

  # Returns the first xml element in the document (see
  # Objectify::Xml.first_element) with the xml data types of the feed and first entry
  # element in the document, used to determine which RubyPicasa object should
  # be initialized to handle the data.
  def xml_data(xml)
    if xml = Objectify::Xml.first_element(xml)
      # There is something wrong with Nokogiri xpath/css search with
      # namespaces. If you are searching a document that has namespaces,
      # it's impossible to match any elements in the root xmlns namespace.
      # Matching just on attributes works though.
      feed, entry = xml.search('//*[@term][@scheme]', xml.namespaces)
      feed_self, entry_self = xml.search('//*[@rel="self"][@type="application/atom+xml"]', xml.namespaces)
      feed_scheme = feed['term'] if feed
      entry_scheme = entry['term'] if entry
      feed_href = feed_self['href']  if feed_self
      entry_href = entry_self['href'] if entry_self
      [xml, feed_scheme, entry_scheme, feed_href, entry_href]
    end
  end

  # Initialize the correct RubyPicasa object depending on the type of feed and
  # entries in the document.
  def class_from_xml(xml)
    xml, feed_scheme, entry_scheme, feed_href, entry_href = xml_data(xml)
    if xml
      r = case feed_scheme
      when /#user$/
        case entry_scheme
        when /#album$/
          RubyPicasa::User.new(xml, self)
        when /#photo$/
          RubyPicasa::RecentPhotos.new(xml, self)
        else
          RubyPicasa::Search.new(xml, self)
        end
      when /#album$/
        RubyPicasa::Album.new(xml, self)
      when /#photo$/
        case entry_scheme
        when /#photo$/
          RubyPicasa::Search.new(xml, self)
        else
          if feed_href && (feed_href.start_with? 'http://picasaweb.google.com/data/feed/api/all')
              RubyPicasa::Search.new(xml, self)
          else
            RubyPicasa::Photo.new(xml, self)
          end
        end
      end
      if r
        r.session = self
        r
      else
        raise RubyPicasa::PicasaError, "Unknown feed type\n feed:  #{ feed_scheme }\n entry: #{ entry_scheme }"
      end
    end
  end
end
