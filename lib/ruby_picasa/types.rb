# Note that in all defined classes I'm ignoring values I don't happen to care
# about. If you care about them, please feel free to add support for them,
# which should not be difficult.
#
# Plural attribute names will be treated as arrays unless the element name
# in the xml document is already plural. (Convention seems to be to label
# repeating elements in the singular.)
#
# If an attribute should be a non-trivial datatype, define the mapping from
# the fully namespaced attribute name to the class you wish to use in the
# class method #types.
#
# Define which namespaces you support in the class method #namespaces. Any
# elements defined in other namespaces are automatically ignored.
module RubyPicasa
  module Shared
    def self.included(target)
      target.attribute :id, 'id'
      target.attributes :updated,
        :title
      target.has_many :links, Objectify::Atom::Link, 'link'
      target.has_one :content, PhotoUrl, 'media:content'
      target.has_many :thumbnails, PhotoUrl, 'media:thumbnail'
      target.namespaces :openSearch, :gphoto, :media
      target.flatten 'media:group'
    end

    def link(rel)
      links.find { |l| l.rel == rel }
    end

    def session=(session)
      @session = session
    end

    def session
      if @session
        @session
      else
        @session = parent.session if parent
      end
    end

    def load(options = {})
      session.get_url(id, options)
    end

    def next
      if link = link('next')
        session.get_url(link.href)
      end
    end

    def previous
      if link = link('previous')
        session.get_url(link.href)
      end
    end
  end

  class PhotoUrl < Objectify::ElementParser
    attributes :url, :height, :width
  end


  class User < Objectify::DocumentParser
    include Shared
    attributes :total_results, # represents total number of albums
      :start_index,
      :items_per_page,
      :thumbnail
    has_many :entries, :Album, 'entry'

    def albums
      entries
    end
  end


  class RecentPhotos < User
    has_many :entries, :Photo, 'entry'

    def photos
      entries
    end

    def albums
      nil
    end
  end


  class Album < Objectify::DocumentParser
    include Shared
    attributes :published,
      :summary,
      :rights,
      :gphoto_id,
      :name,
      :access,
      :numphotos, # number of pictures in this album
      :total_results, # number of pictures matching this 'search'
      :start_index,
      :items_per_page,
      :allow_downloads
    has_many :entries, :Photo, 'entry'

    def public?
      rights == 'public'
    end

    def private?
      rights == 'private'
    end

    def photos(options = {})
      if entries.blank? and !@photos_requested
        @photos_requested = true
        session ||= parent.session
        self.entries = session.photos(options.merge(:album_id => id))
      else
        entries
      end
    end
  end


  class Photo < Objectify::DocumentParser
    include Shared
    attributes :published,
      :summary,
      :gphoto_id,
      :version, # can use to determine if need to update...
      :position,
      :albumid, # useful from the recently updated feed for instance.
      :width,
      :height,
      :description,
      :keywords,
      :credit
    has_one :content, PhotoUrl, 'media:content'
    has_one :author, Objectify::Atom::Author, 'author'

    def url(thumb_name = nil)
      if thumb_name
        thumbnails.find { |t| t }.url
      else
        content.url
      end
    end
  end


  class Search < Album
  end
end

