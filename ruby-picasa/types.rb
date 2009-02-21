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
  class User < XmlParser
    attr_accessor :id,
      :updated,
      :title,
      :links,
      :total_results, # represents total number of albums
      :start_index,
      :items_per_page,
      :thumbnail,
      :entries

    def self.namespaces
      %w[openSearch gphoto]
    end

    # Always use fully qualified element name.
    #
    # If it returns :self, just carry on into the definition without assigning
    # that property to anything and keep on using the same object. This is used
    # for media:group where the xml nests but keeps on defining the same object
    # and does note repeat. XML is retarded.
    def self.types
      { 'link' => Link,
        'entry' => Album,
        'media:content' => PhotoUrl,
        'media:thumbnail' => PhotoUrl }
    end
  end


  class Album < XmlParser
    attr_accessor :id,
      :published,
      :updated,
      :title,
      :summary,
      :rights,
      :links,
      :gphoto_id,
      :name,
      :access,
      :numphotos, # number of pictures in this album
      :content,
      :thumbnails,
      :total_results, # number of pictures matching this 'search'
      :start_index,
      :items_per_page,
      :allow_downloads,
      :entries

    def self.namespaces
      %w[openSearch gphoto media]
    end

    def self.types
      { 'link' => Link,
        'entry' => Photo,
        'media:content' => PhotoUrl,
        'media:thumbnail' => PhotoUrl,
        'media:group' => :self }
    end
  end

  class Search < Album
    def initialize(q, start_index = 1, max_results = 10)
      @q = q
      @start_index = start_index
      @max_results = max_results
      xml = open("http://picasaweb.google.com/data/feed/api/all?q=#{ CGI.escape(q.to_s) }&start-index=#{ CGI.escape(start_index.to_s) }&max-results=#{ CGI.escape(max_results.to_s) }").read
      super(xml)
    end

    def next_results
      Search.new(@q, @start_index + @max_results, @max_results)
    end
  end

  class Link < AttributeParser
    attr_accessor :rel, :type, :href
  end

  class Photo < XmlParser
    attr_accessor :id,
      :published,
      :updated,
      :title,
      :summary,
      :links,
      :gphoto_id,
      :version, # can use to determine if need to update...
      :position,
      :albumid, # useful from the recently updated feed for instance.
      :width,
      :height,
      :description,
      :keywords,
      :content,
      :thumbnails

    def self.namespaces
      %w[gphoto media]
    end
    def self.types
      { 'link' => Link,
        'media:content' => PhotoUrl,
        'media:thumbnail' => PhotoUrl,
        'media:group' => :self }
    end
  end

  class PhotoUrl < AttributeParser
    attr_accessor :url, :height, :width
  end
end

