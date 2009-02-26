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
  class PhotoUrl < Objectify::ElementParser
    attributes :url, :height, :width
  end


  class ThumbnailUrl < PhotoUrl
    def thumb_name
      url.scan(%r{/([^/]+)/[^/]+$}).flatten.compact.first
    end
  end


  class Base < Objectify::DocumentParser
    namespaces :openSearch, :gphoto, :media
    flatten 'media:group'

    attribute :id, 'id'
    attributes :updated, :title

    has_many :links, Objectify::Atom::Link, 'link'
    has_one :content, PhotoUrl, 'media:content'
    has_many :thumbnails, ThumbnailUrl, 'media:thumbnail'
    has_one :author, Objectify::Atom::Author, 'author'

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


  class User < Base
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

    undef albums
  end


  class Album < Base
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
        self.session ||= parent.session
        self.entries = session.album(id, options).entries if self.session
      else
        entries
      end
    end
  end


  class Search < Album
  end


  class Photo < Base
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
    has_one :author, Objectify::Atom::Author, 'author'

    def url(thumb_name = nil)
      if thumb_name
        if thumb = thumbnail(thumb_name)
          thumb.url
        end
      else
        content.url
      end
    end

    def thumbnail(thumb_name)
      thumbnails.find { |t| t.thumb_name == thumb_name }
    end
  end
end

