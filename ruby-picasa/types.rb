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


  class User < Objectify::DocumentParser
    attr_accessor :session
    attribute :id, 'id'
    attributes :updated,
      :title,
      :total_results, # represents total number of albums
      :start_index,
      :items_per_page,
      :thumbnail
    has_many :links, Objectify::Atom::Link, 'link'
    has_many :entries, :Album, 'entry'
    has_one :content, PhotoUrl, 'media:content'
    has_many :thumbnails, PhotoUrl, 'media:thumbnail'
    namespaces :openSearch, :gphoto
    flatten 'media:group'

    def albums
      entries
    end
  end


  class Album < Objectify::DocumentParser
    attr_accessor :session
    attribute :id, 'id'
    attributes :published,
      :updated,
      :title,
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
    has_many :links, Objectify::Atom::Link, 'link'
    has_many :entries, :Photo, 'entry'
    has_one 'content', PhotoUrl, 'media:content'
    has_many 'thumbnails', PhotoUrl, 'media:thumbnail'
    flatten 'media:group'
    namespaces :openSearch, :gphoto, :media

    def public?
      rights == 'public'
    end

    def private?
      rights == 'private'
    end

    def get
      session ||= parent.session
      session.album(id)
    end

    def photos
      entries
    end
  end


  class Photo < Objectify::DocumentParser
    attribute :id, 'id'
    attributes :published,
      :updated,
      :title,
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
    has_many 'links', Objectify::Atom::Link, 'link'
    has_one 'content', PhotoUrl, 'media:content'
    has_many 'thumbnails', PhotoUrl, 'media:thumbnail'
    namespaces :gphoto, :media
    flatten 'media:group'
  end


  class Search < Album
    def initialize(q, start_index = 1, max_results = 10)
      raise "Incorect query type." unless q.is_a? String
      @q = q
      @start_index = start_index
      @max_results = max_results
      request = "http://#{ Picasa.host }#{ Picasa.path('all', :q => q, :start_index => start_index, :max_results => max_results) }"
      xml = Net::HTTP.get(URI.parse(request))
      super(xml)
    end

    def next_results
      Search.new(@q, @start_index + @max_results, @max_results)
    end
  end
end

