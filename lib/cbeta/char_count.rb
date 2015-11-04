class CBETA::CharCount
  def initialize(xml_root)
    @xml_root = xml_root
    @result = {}
  end
  
  def char_count(canon=nil)
    stat_all if canon.nil?
    stat_canon(canon)
    @result
  end
  
  private
    
  def handle_node(e)
    return if e.comment?
    return handle_text(e) if e.text?
    return if %w(foreign mulu rdg reg sic).include? e.name
    
    case e.name
    when 'g'    then @result[@work] += 1
    when 'note' then handle_note(e)
    when 't'    then handle_t(e)
    else traverse(e)
    end
  end
  
  def handle_note(e)
    if %w(inline interlinear).include? e['place']
      traverse(e)
    end
  end
  
  def handle_t(e)
    if e.has_attribute? 'place' and e['place'].include? 'foot'
      return
    end
    traverse(e)
  end
  
  def handle_text(e)
    s = e.content().chomp
    return if s.empty?
    return if e.parent.name == 'app'

    # cbeta xml 文字之間會有多餘的換行
    s.gsub!(/[\n\r]/, '')
    
    @result[@work] += s.size
  end
      
  def stat_all
    Dir.entries(@xml_root).sort.each do |canon|
      next if canon.start_with? '.'
      next if canon == 'schema'
      stat_canon(canon)
    end
  end
  
  def stat_canon(canon)
    return if canon.nil?
    puts 'stat canon: ' + canon
    folder = File.join(@xml_root, canon)
    Dir.entries(folder).sort.each do |vol|
      next if vol.start_with? '.'
      p = File.join(folder, vol)
      stat_vol(p)
    end
  end
  
  def stat_file(fn)
    @work = File.basename(fn, '.xml')
    @work.sub!(/^([A-Z])\d{2,3}n(.*)$/, '\1\2')
    @work = 'T0220' if @work.start_with?('T0220')
    unless @result.key? @work
      puts "stat work: #{@work}"
      @result[@work] = 0 
    end
    
    doc = CBETA.open_xml(fn)
    body = doc.at_xpath('/TEI/text/body')
    traverse(body)
  end
  
  def stat_vol(vol_folder)
    Dir.entries(vol_folder).sort.each do |f|
      next if f.start_with? '.'
      p = File.join(vol_folder, f)
      stat_file(p)
    end
  end
  
  def traverse(e)
    e.children.each { |c| 
      handle_node(c)
    }
  end
  
end