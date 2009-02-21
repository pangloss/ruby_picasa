require 'cgi'
require 'nokogiri'
require 'active_support'

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
  end

  class Xml
    def initialize(xml)
      return if xml.nil?
      if xml.is_a? String
        xml = Nokogiri::XML(xml) 
        # skip the <?xml?> tag
        xml = xml.child if xml.name == 'document'
      end
      primary_xml_element(xml) if xml
    end

    def xml_text_to_value(value)
      case value
      when 'true'
        true
      when 'false'
        false
      when /\A\d{4}-\d\d-\d\dT(\d\d[:.]){3}\d{3}\w\Z/
        DateTime.parse(value)
      when /\A\d+\Z/
        value.to_i
      when /\A\d+\.\d+\Z/
        value.to_f
      else
        value
      end
    end
  end

  class AttributeParser < Xml
    def primary_xml_element(xml)
      xml.attributes.each do |name, value|
        method = "#{ name }="
        if respond_to? method
          send(method, xml_text_to_value(value))
        end
      end
    end
  end

  class XmlParser < Xml
    def primary_xml_element(xml)
      parse_xml(xml.child)
    end

    def parse_xml(xml)
      while xml
        read_xml_element(xml)
        xml = xml.next
      end
    end

    def method_name(x)
      names = []
      if x.namespace
        names << ["#{ x.namespace }_#{ x.name.pluralize }", true]
        names << ["#{ x.namespace }_#{ x.name }", false]
      end
      names << [x.name.pluralize, true]
      names << [x.name, false]
      name, plural = names.find do |n, _|
        respond_to?("#{ n.underscore }=")
      end
      if name
        [name.underscore, "#{ name.underscore }=", plural]
      end
    end

    def read_xml_element(x)
      return if x.is_a? Nokogiri::XML::Text
      return unless self.class.namespace?(x.namespace) if x.namespace
      value = nil
      full_name = "#{ x.namespace }:#{ x.name }"
      if type = self.class.types[full_name]
        if type == :self
          parse_xml(x.child)
          return
        else
          set_xml_property(x) { type.new(x) }
        end
      else
        set_xml_property(x) { xml_text_to_value(x.text) }
      end
    end

    def set_xml_property(x)
      getter, setter, plural = method_name(x)
      if getter
        value = nil
        if plural
          value = send(getter)
          value ||= []
          value << yield
        else
          value = yield
        end
        send(setter, value)
      end
    end
  end

  class User < XmlParser
    attr_accessor :id,
      :updated,
      :title,
      :total_results, # represents total number of albums
      :start_index,
      :items_per_page,
      :thumbnail,
      :entries

    def self.namespaces
      %w[openSearch gphoto]
    end
    def self.namespace?(ns)
      namespaces.include? ns
    end
    def self.types
      { 'link' => Link,
        'entry' => Album,
        'media:content' => PhotoUrl,
        'media:thumbnail' => PhotoUrl }
    end
  end


  # Note that in all defined classes I'm ignoring values I don't happen to care
  # about. If you care about them, please feel free to add support for them.
  class Album < XmlParser

    # Try first "#{ namespace }_#{ element.pluralize }".underscore, then not
    # plural, then without namespace plural and not plural.
    #
    # Plural is always an array that gets pushed into.
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
    def self.namespace?(ns)
      namespaces.include? ns
    end

    # always use full name
    #
    # If it returns :self, just carry on into the definition without assigning
    # that property to anything and keep on using the same object. This is used
    # for media:group where the xml nests but keeps on defining the same object
    # and does note repeat. XML is retarded.
    def self.types
      { 'link' => Link,
        'entry' => Photo,
        'media:content' => PhotoUrl,
        'media:thumbnail' => PhotoUrl,
        'media:group' => :self }
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
    def self.namespace?(ns)
      namespaces.include? ns
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
    def initialize(xml)
    end
  end
end
