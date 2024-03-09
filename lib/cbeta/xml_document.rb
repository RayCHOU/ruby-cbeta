require 'nokogiri'

class CBETA::XMLDocument
  PASS = %w(back graphic mulu rdg sic teiHeader)

  def initialize(string_or_io)
    @doc = Nokogiri::XML(string_or_io)
    @doc.remove_namespaces!
    @gaiji = CBETA::Gaiji.new
  end

  def to_text
    @format = 'text'
    @gaiji_norm = [true]
    @next_line_buf = ''
    traverse(@doc.root)
  end

  private

  def e_anchor(e)
    if e.has_attribute?('type')
      if e['type'] == 'circle'
        return '◎'
      end
    end

    ''
  end

  def e_app(e)
    traverse(e)
  end

  def e_body(e)
    traverse(e)
  end

  def e_byline(e)
    traverse(e) + "\n"
  end

  def e_caesura(e)
    '　'
  end

  def e_cell(e)
    traverse(e) + "\n"
  end
  
  def e_corr(e)
    traverse(e)
  end
  
  def e_date(e)
    traverse(e)
  end

  def e_dialog(e)
    traverse(e)
  end

  def e_div(e)
    traverse(e)
  end
  
  def e_docNumber(e)
    traverse(e) + "\n"
  end

  def e_event(e)
    traverse(e) + "\n"
  end

  def e_figure(e)
    traverse(e) + "\n"
  end

  def e_foreign(e)
    return '' if e.key?('place') and e['place'].include?('foot')
    traverse(e)
  end

  def e_g(e)
    if @gaiji_norm.last
      cb_priority = %w(uni_char norm_uni_char norm_big5_char composition)
    else
      cb_priority = %w(uni_char composition)
    end

    gid = e['ref'][1..-1]
    r = @gaiji.to_s(gid, cb_priority:)
    abort "Line:#{__LINE__} 缺字處理失敗:#{gid}" if r.nil?
    r
  end

  def e_head(e)
    traverse(e) + "\n"
  end

  def e_hi(e)
    traverse(e)
  end

  def e_item(e)
    r = "\n"

    list_level = e.xpath('ancestor::list').size
    r << '　' * (list_level - 1)
    r << traverse(e)
    if e.key? 'n'
      r = e['n'] + r
    end
    r
  end

  def e_jhead(e)
    traverse(e)
  end

  def e_juan(e)
    traverse(e) + "\n"
  end

  def e_l(e)
    r = traverse(e)
    r << "\n" unless @lg_type == 'abnormal'
    r
  end

  def e_lb(e)
    return '' if e['type']=='old'
    r = ''
    r << "\n" if @p_type == 'pre'
    unless @next_line_buf.empty?
      r << @next_line_buf + "\n"
      @next_line_buf = ''
    end
    r
  end

  def e_lem(e)
    traverse(e)
  end

  def e_lg(e)
    traverse(e)
  end

  def e_list(e)
    r = traverse(e)
    r << "\n\n" unless e.parent.name == 'item'
    r
  end

  def e_milestone(e)
    ''
  end

  def e_note(e)
    if e.has_attribute?('place')
      if "inline inline2 interlinear".include?(e['place'])
        r = traverse(e)
        return "(#{r})"
      end
    end
    ''
  end

  def e_p(e)
    @p_type = e['type']
    r = traverse(e) + "\n"
    @p_type = nil
    r
  end

  def e_pb(e)
    ''
  end

  def e_reg(e)
    r = ''
    choice = e.at_xpath('ancestor::choice')
    r = traverse(e) if choice.nil?
    r
  end

  def e_row(e)
    traverse(e) + "\n"
  end

  def e_sg(e)
    '(' + traverse(e) + ')'
  end

  # speech
  def e_sp(e)
    traverse(e)
  end

  def e_space(e)
    return '' if e['quantity']=='0'
    '　' * e['quantity'].to_i
  end

  def e_t(e)
    if e.has_attribute? 'place'
      return '' if e['place'].include? 'foot'
    end
    r = traverse(e)

    # 如果不是雙行對照
    tt = e.at_xpath('ancestor::tt')
    unless tt.nil? 
      return r if %w(app single-line).include? tt['type']
      return r if tt['place'] == 'inline'
      return r if tt['rend'] == 'normal'
    end

    # 處理雙行對照
    i = e.xpath('../t').index(e)
    case i
    when 0
      return r + '　'
    when 1
      @next_line_buf << r + '　'
      return ''
    else
      return r
    end
  end

  def e_table(e)
    traverse(e) + "\n"
  end

  def e_term(e)
    norm = true
    if e['behaviour'] == "no-norm"
      norm = false
    end
    @gaiji_norm.push norm
    r = traverse(e)
    @gaiji_norm.pop
    r
  end

  def e_text(e)
    norm = true
    if e['behaviour'] == "no-norm"
      norm = false
    end
    @gaiji_norm.push norm
    r = traverse(e)
    @gaiji_norm.pop
    r
  end

  def e_tt(e)
    traverse(e)
  end

  def e_unclear(e)
    r = traverse(e)
    r = '▆' if r.empty?
    r
  end


  def handle_node(e)
    return '' if e.comment?
    return handle_text(e) if e.text?
    return '' if PASS.include?(e.name)
    send("e_#{e.name}", e)
  end

  def handle_text(e)
    s = e.content().chomp
    return '' if s.empty?
    return '' if e.parent.name == 'app'

    # cbeta xml 文字之間會有多餘的換行
    r = s.gsub(/[\n\r]/, '')

    if @format == 'html'
      r = CGI.escapeHTML(r) # 把 & 轉為 &amp;
    end

    r
  end

  def traverse(e)
    r = ''
    e.children.each do |c| 
      r << handle_node(c)
    end
    r
  end

end
