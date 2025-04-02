module CbetaShare
  def each_canon(xml_root)
    Dir.entries(xml_root).sort.each do |c|
      next unless c.match(/^#{CBETA::CANON}$/)
      yield(c)
    end
  end

  def to_html(e)
    e.to_xml(
      encoding: 'UTF-8',
      save_with: Nokogiri::XML::Node::SaveOptions::AS_XML |
                 Nokogiri::XML::Node::SaveOptions::NO_EMPTY_TAGS
    )
  end

end
