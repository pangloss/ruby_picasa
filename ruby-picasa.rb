require 'active_support'
require 'active_support/inflections'
require 'cgi'
require 'nokogiri'

require 'ruby-picasa/xml'
require 'ruby-picasa/types'

require 'open-uri'

module RubyPicasa
  class Picasa

    attr_accessor :token

    # I'll do the CGI::escape, thank you.
    def one_time_access(return_to_url, one_time = true)
      # get auth
      session = one_time ? '0' : '1'
      secure = '0'
      return_to_url = CGI.escape(return_to_url)
      "https://www.google.com/accounts/AuthSubRequest?scope=http%3A%2F%2Fpicasaweb.google.com%2Fdata%2F&session=#{ session }&secure=#{ secure }&next=#{ return_to_url }"
      #return @token or nil
    end

    def authorize(return_to_url)
      if one_time_access(return_to_url, false)
        do_auth_etc
        #return @token or nil
      end
    end

    def user
      xml = request_albums_feed
      User.new(xml)
    end

    def albums
      user.entries
    end

    # album contains photos
    def album(id_or_url)
      xml = request_album_feed
      Album.new(xml)
    end

    def search(q, start_index = 1, max_results = 10)
      Search.new(q, start_index, max_results)
    end
  end
end

