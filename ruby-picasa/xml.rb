module RubyPicasa
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
      value = value.strip
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
      xml.attributes.keys.each do |name|
        method = "#{ name }="
        if respond_to? method
          send(method, xml_text_to_value(xml[name]))
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
        names << ["#{ x.namespace }_#{ x.name }", false]
        names << ["#{ x.namespace }_#{ x.name.pluralize }", true]
      end
      names << [x.name, false]
      names << [x.name.pluralize, true]
      name, plural = names.find do |n, _|
        respond_to?("#{ n.underscore }=")
      end
      if name
        [name.underscore, "#{ name.underscore }=", plural]
      end
    end

    def read_xml_element(x)
      return if x.is_a? Nokogiri::XML::Text
      return unless self.class.namespaces.include?(x.namespace) if x.namespace
      value = nil
      full_name = x.name
      full_name = "#{ x.namespace }:#{ x.name }" if x.namespace
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
end
