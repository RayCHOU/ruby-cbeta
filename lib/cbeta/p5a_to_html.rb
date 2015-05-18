require 'cgi'
require 'date'
require 'fileutils'
require 'json'
require 'nokogiri'
require 'set'

# 內容不輸出的元素
PASS=['back', 'teiHeader']

# 某版用字缺的符號
MISSING = '－'

# 處理 CBETA XML P5a
#
# CBETA XML P5a 可由此取得: https://github.com/cbeta-git/xml-p5a
#
# 轉檔規則請參考: http://wiki.ddbc.edu.tw/pages/CBETA_XML_P5a_轉_HTML
class CBETA::P5aToHTML

  # xml_root:: 來源 CBETA XML P5a 路徑
  # out_root:: 輸出 HTML 路徑
  def initialize(xml_root, out_root)
    @xml_root = xml_root
    @out_root = out_root
    @gaijis = CBETA::Gaiji.new

    # 載入 unicode 1.1 字集列表
    fn = File.join(File.dirname(__FILE__), 'unicode-1.1.json')
    json = File.read(fn)
    @unicode1 = JSON.parse(json)
  end

  # 將 CBETA XML P5a 轉為 HTML
  #
  # 例如 轉出大正藏第一冊
  #
  #   x2h = CBETA::P5aToHTML.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
  #   x2h.convert('T01')
  #
  # 例如 轉出大正藏全部
  #
  #   x2h = CBETA::P5aToHTML.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
  #   x2h.convert('T')
  #
  # T 是大正藏的 ID, CBETA 的藏經 ID 系統請參考: http://www.cbeta.org/format/id.php
  def convert(arg=nil)
    return convert_all if arg.nil?

    arg.upcase!
    if arg.size == 1
      handle_collection(arg)
    else
      if arg.include? '..'
        arg.match(/^([^\.]+?)\.\.([^\.]+)$/) {
          handle_vols($1, $2)
        }
      else
        handle_vol(arg)
      end
    end
  end

  private

  def convert_all
    Dir.foreach(@xml_root) { |c|
      next unless c.match(/^[A-Z]$/)
      handle_collection(c)
    }
  end

  def handle_anchor(e)
    id = e['id']
    if e.has_attribute?('id')
      if id.start_with?('nkr_note_orig')
        note = @notes[id]
        note_text = traverse(note)
        n = id[/^nkr_note_orig_(.*)$/, 1]
        @back[@juan] += "<span class='footnote' id='n#{n}'>#{note_text}</span>\n"
        return "<a class='noteAnchor' href='#n#{n}'></a>"
      elsif id.start_with? 'fx'
        return "<span class='star'>[＊]</span>"
      end
    end

    if e.has_attribute?('type')
      if e['type'] == 'circle'
        return '◎'
      end
    end

    ''
  end

  def handle_app(e)
    r = ''
    if e['type'] == 'star'
      c = e['corresp'][1..-1]
      r = "<a class='noteAnchor star' href='#n#{c}'></a>"
    end
    r + traverse(e)
  end

  def handle_byline(e)
    r = '<p class="byline">'
    r += "<span class='lineInfo'>#{@lb}</span>"
    r += traverse(e)
    r + '</p>'
  end

  def handle_collection(c)
    @series = c
    puts 'handle_collection ' + c
    folder = File.join(@xml_root, @series)
    Dir.foreach(folder) { |vol|
      next if ['.', '..', '.DS_Store'].include? vol
      handle_vol(vol)
    }
  end

  def handle_corr(e)
    r = ''
    if e.parent.name == 'choice'
      sic = e.parent.at_xpath('sic')
      unless sic.nil?
        @dila_note += 1
        r = "<a class='noteAnchor dila' href='#dila_note#{@dila_note}'></a>"

        note = @orig
        sic_text = traverse(sic, 'back')
        if sic_text.empty?
          note += MISSING
        else
          note += sic_text
        end
        @back[@juan] += "<span class='footnote_dila' id='dila_note#{@dila_note}'>#{note}</span>\n"
      end
    end
    r + "<span class='cbeta'>%s</span>" % traverse(e)
  end

  def handle_div(e)
    @div_count += 1
    n = @div_count
    if e.has_attribute? 'type'
      @open_divs << e
      r = traverse(e)
      @open_divs.pop
      return "<!-- begin div#{n}--><div class='div-#{e['type']}'>#{r}</div><!-- end of div#{n} -->"
    else
      return traverse(e)
    end
  end

  def handle_figure(e)
    "<p class='figure'>%s</p>" % traverse(e)
  end

  def handle_g(e, mode)
    # if 有 <mapping type="unicode">
    #   if 在 unicode 1.1 範圍裡
    #     直接採用
    #   else
    #     預設呈現 unicode, 但仍包缺字資訊，供點選開 popup
    # else if 有 <mapping type="normal_unicode">
    #   預設呈現 normal_unicode, 但仍包缺字資訊，供點選開 popup
    # else if 有 normalized form
    #   預設呈現 normalized form, 但仍包缺字資訊，供點選開 popup
    # else
    #   預設呈現組字式, 但仍包缺字資訊，供點選開 popup
    gid = e['ref'][1..-1]
    g = @gaijis[gid]
    abort "Line:#{__LINE__} 無缺字資料:#{gid}" if g.nil?
    zzs = g['zzs']
    
    if mode == 'txt'
      return g['roman'] if gid.start_with?('SD')
      if zzs.nil?
        abort "缺組字式：#{g}"
      else
        return zzs
      end
    end

    @char_count += 1

    if gid.start_with?('SD')
      case gid
      when 'SD-E35A'
        return '（'
      when 'SD-E35B'
        return '）'
      else
        return "<span class='siddam' roman='#{g['roman']}' code='#{gid}' char='#{g['sd-char']}'/>"
      end
    end
    
    if gid.start_with?('RJ')
      return "<span class='ranja' roman='#{g['roman']}' code='#{gid}' char='#{g['rj-char']}'/>"
    end
   
    default = ''
    if g.has_key?('unicode')
      if @unicode1.include?(g['unicode'])
        return g['unicode-char'] # unicode 1.1 直接用
      else
        default = g['unicode-char']
      end
    end

    nor = ''
    if g.has_key?('normal_unicode')
      nor = g['normal_unicode']
      default = nor if default.empty?
    end

    if g.has_key?('normal')
      nor += ', ' unless nor==''
      nor += g['normal']
      default = g['normal'] if default.empty?
    end

    default = zzs if default.empty?
    
    href = 'http://dict.cbeta.org/dict_word/gaiji-cb/%s/%s.gif' % [gid[2, 2], gid]
    unless @back[@juan].include?(href)
      @back[@juan] += "<span id='#{gid}' class='gaijiInfo' figure_url='#{href}' zzs='#{zzs}' nor='#{nor}'>#{default}</span>\n"
    end
    "<a class='gaijiAnchor' href='##{gid}'>#{default}</a>"
  end

  def handle_graphic(e)
    url = File.basename(e['url'])
    "<span imgsrc='#{url}' class='graphic'></span>"
  end

  def handle_head(e)
    r = ''
    unless e['type'] == 'added'
      r = "<p class='head'>%s</p>" % traverse(e)
    end
    r
  end

  def handle_item(e)
    "<li>%s</li>\n" % traverse(e)
  end

  def handle_juan(e)
    "<p class='juan'>%s</p>" % traverse(e)
  end

  def handle_l(e)
    if @lg_type == 'abnormal'
      return traverse(e)
    end

    @in_l = true

    doc = Nokogiri::XML::Document.new
    cell = doc.create_element('div')
    cell['class'] = 'lg-cell'
    cell.inner_html = traverse(e)
    
    if @first_l
      parent = e.parent()
      if parent.has_attribute?('rend')
        indent = parent['rend'].scan(/text-indent:[^:]*/)
        unless indent.empty?
          cell['style'] = indent[0]
        end
      end
      @first_l = false
    end
    r = cell.to_s
    
    unless @lg_row_open
      r = "\n<div class='lg-row'>" + r
      @lg_row_open = true
    end
    @in_l = false
    r
  end

  def handle_lb(e)
    @char_count = 1
    @lb = e['n']
    line_head = @sutra_no + '_p' + e['n']
    r = ''
    #if e.parent.name == 'lg' and $lg_row_open
    if @lg_row_open && !@in_l
      # 每行偈頌放在一個 lg-row 裡面
      # T46n1937, p. 914a01, l 包雙行夾註跨行
      # T20n1092, 337c16, lb 在 l 中間，不結束 lg-row
      r += "</div><!-- end of lg-row -->"
      @lg_row_open = false
    end
    r + "<span class='lb' \nid='#{line_head}'>#{line_head}</span>"
  end

  def handle_lem(e)
    r = ''
    w = e['wit']
    if w.include? 'CBETA' and not w.include? @orig
      @dila_note += 1
      r = "<a class='noteAnchor dila' href='#dila_note#{@dila_note}'></a>"
      r += "<span class='cbeta'>%s</span>" % traverse(e)

      note = lem_note_cf(e)
      note += lem_note_rdg(e)
      @back[@juan] += "<span class='footnote_dila' id='dila_note#{@dila_note}'>#{note}</span>\n"
    else
      r = traverse(e)
    end
    r
  end

  def handle_lg(e)
    r = ''
    @lg_type = e['type']
    if @lg_type == 'abnormal'
      r = "<p class='lg-abnormal'>" + traverse(e) + "</p>"
    else
      @first_l = true
      doc = Nokogiri::XML::Document.new
      node = doc.create_element('div')
      node['class'] = 'lg'
      if e.has_attribute?('rend')
        rend = e['rend'].gsub(/text-indent:[^:]*/, '')
        node['style'] = rend
      end
      @lg_row_open = false
      node.inner_html = traverse(e)
      if @lg_row_open
        node.inner_html += '</div><!-- end of lg -->'
        @lg_row_open = false
      end
      r = "\n" + node.to_s
    end
    r
  end

  def handle_list(e)
    "<ul>%s</ul>" % traverse(e)
  end

  def handle_milestone(e)
    r = ''
    if e['unit'] == 'juan'

      r += "</div>" * @open_divs.size  # 如果有 div 跨卷，要先結束, ex: T55n2154, p. 680a29, 跨 19, 20 兩卷
      @juan = e['n'].to_i
      @back[@juan] = @back[0]
      r += "<juan #{@juan}>"
      @open_divs.each { |d|
        r += "<div class='#{d['type']}'>"
      }
    end
    r
  end

  def handle_mulu(e)
    r = ''
    if e['type'] == '品'
      @pass << false
      r = "<mulu class='pin' s='%s'/>" % traverse(e, 'txt')
      @pass.pop
    end
    r
  end

  def handle_node(e, mode)
    return '' if e.comment?
    return handle_text(e, mode) if e.text?
    return '' if PASS.include?(e.name)
    r = case e.name
    when 'anchor'    then handle_anchor(e)
    when 'app'       then handle_app(e)
    when 'byline'    then handle_byline(e)
    when 'corr'      then handle_corr(e)
    when 'div'       then handle_div(e)
    when 'figure'    then handle_figure(e)
    when 'foreign'   then ''
    when 'g'         then handle_g(e, mode)
    when 'graphic'   then handle_graphic(e)
    when 'head'      then handle_head(e)
    when 'item'      then handle_item(e)
    when 'juan'      then handle_juan(e)
    when 'l'         then handle_l(e)
    when 'lb'        then handle_lb(e)
    when 'lem'       then handle_lem(e)
    when 'lg'        then handle_lg(e)
    when 'list'      then handle_list(e)
    when 'mulu'      then handle_mulu(e)
    when 'note'      then handle_note(e)
    when 'milestone' then handle_milestone(e)
    when 'p'         then handle_p(e)
    when 'rdg'       then ''
    when 'reg'       then ''
    when 'sic'       then ''
    when 'sg'        then handle_sg(e)
    when 't'         then handle_t(e)
    else traverse(e)
    end
    r
  end


  def handle_note(e)
    n = e['n']
    if e.has_attribute?('type')
      t = e['type']
      case t
      when 'equivalent'
        return ''
      when 'orig'
        @pass << false
        s = traverse(e)
        @pass.pop
        @back[@juan] += "<span class='footnote_orig' id='n#{n}'>#{s}</span>\n"

        if @mod_notes.include? n
          return ''
        else
          return "<a class='noteAnchor' href='#n#{n}'></a>"
        end
      when 'mod'
        @pass << false
        s = traverse(e)
        @pass.pop
        @back[@juan] += "<span class='footnote_cb' id='n#{n}'>#{s}</span>\n"
        return "<a class='noteAnchor' href='#n#{n}'></a>"
      when 'rest'
        return ''
      else
        return '' if t.start_with?('cf')
      end
    end

    if e.has_attribute?('resp')
      return '' if e['resp'].start_with? 'CBETA'
    end

    if e.has_attribute?('place') && e['place']=='inline'
      r = traverse(e)
      return "<span class='doube-line-note'>#{r}</span>"
    else
      return traverse(e)
    end
  end

  def handle_p(e)
    r = '<p>'
    r += "<span class='lineInfo'>#{@lb}</span>"
    r += traverse(e)
    r + '</p>'
  end

  def handle_sg(e)
    '(' + traverse(e) + ')'
  end

  def handle_sutra(xml_fn)
    puts "handle sutra #{xml_fn}"
    @back = { 0 => '' }
    @char_count = 1
    @dila_note = 0
    @div_count = 0
    @in_l = false
    @juan = 0
    @lg_row_open = false
    @mod_notes = Set.new
    @open_divs = []
    @sutra_no = File.basename(xml_fn, ".xml")

    text = parse_xml(xml_fn)

    # 註標移到 lg-cell 裡面，不然以 table 呈現 lg 會有問題
    text.gsub!(/(<a class='noteAnchor'[^>]*><\/a>)(<div class="lg-cell"[^>]*>)/, '\2\1')
    
    juans = text.split(/(<juan \d+>)/)
    open = false
    fo = nil
    juan_no = nil
    fn = ''
    buf = ''
    # 一卷一檔
    juans.each { |j|
      if j =~ /<juan (\d+)>$/
        juan_no = $1.to_i
        fn = "#{@sutra_no}_%03d.htm" % juan_no
        output_path = File.join(@out_folder, fn)
        fo = File.open(output_path, 'w')
        open = true
        s = <<eos
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <meta name="filename" content="#{fn}" />
  <title>#{@title}</title>
</head>
<body>
<!-- 
  來源 XML CBETA P5a: https://github.com/cbeta-org/xml-p5a.git
  轉檔程式: Dropbox/DILA-DA/cbeta-html/bin/x2h.rb Version #{Date.today}
  說明文件: http://wiki.ddbc.edu.tw/pages/CBETA_XML_P5a_%E8%BD%89_HTML
-->
<div id='body'>
eos
        fo.write(s)
        fo.write(buf)
        buf = ''
      elsif open
        fo.write(j + "\n</div><!-- end of div[@id='body'] -->\n")
        fo.write("<div id='back'>\n" + @back[juan_no] + "</div>\n")
        fo.write('</body></html>')
        fo.close
      else
        buf = j
      end
    }
  end

  def handle_t(e)
    if e.has_attribute? 'place'
      return '' if e['place'].include? 'foot'
    end
    traverse(e)
  end

  def handle_text(e, mode)
    s = e.content().chomp
    return '' if s.empty?
    return '' if e.parent.name == 'app'

    # cbeta xml 文字之間會有多餘的換行
    r = s.gsub(/[\n\r]/, '')

    # 把 & 轉為 &amp;
    r = CGI.escapeHTML(r)

    # 正文區的文字外面要包 span
    if @pass.last and mode=='html'
      r = "<span class='t' l='#{@lb}' w='#{@char_count}'>#{r}</span>"
      @char_count += r.size
    end
    r
  end

  def handle_vol(vol)
    puts 'x2h ' + vol
    if vol.start_with? 'T'
      @orig = "【大】"
    else
      abort "未處理底本"
    end
    @vol = vol
    @series = vol[0]
    @out_folder = File.join(@out_root, @series, vol)
    FileUtils.remove_dir(@out_folder, force=true)
    FileUtils::mkdir_p @out_folder
    
    source = File.join(@xml_root, @series, vol)
    Dir[source+"/*"].each { |f|
      handle_sutra(f)
    }
  end

  def handle_vols(v1, v2)
    @series = v1[0]
    folder = File.join(IN, @series)
    Dir.foreach(folder) { |vol|
      next if vol < v1
      next if vol > v2
      handle_vol(vol)
    }
  end

  def lem_note_cf(e)
    # ex: T32n1670A.xml, p. 703a16
    # <note type="cf1">K30n1002_p0257a01-a23</note>
    refs = []
    e.xpath('./note').each { |n|
      if n.key?('type') and n['type'].start_with? 'cf'
        refs << n.content
      end
    }
    if refs.empty?
      ''
    else
      '修訂依據：' + refs.join('；') + '。'
    end
  end

  def lem_note_rdg(lem)
    r = ''
    app = lem.parent
    @pass << false
    app.xpath('rdg').each { |rdg|
      if rdg['wit'].include? @orig
        s = traverse(rdg, 'back')
        s = MISSING if s.empty?
        r += @orig + s
      end
    }
    @pass.pop
    r += '。' unless r.empty?
    r
  end

  def open_xml(fn)
    s = File.read(fn)

    if fn.include? 'T16n0657'
      # 這個地方 雙行夾註 跨兩行偈頌
      # 把 lb 移到 note 結束之前
      # 讓 lg-row 先結束，再結束雙行夾註
      s.sub!(/(<\/note>)(\n<lb n="0206b29" ed="T"\/>)/, '\2\1')
    end

    # <milestone unit="juan"> 前面的 lb 屬於新的這一卷
    s.gsub!(/((?:<pb [^>]+>\n?)?<lb [^>]+>\n?)(<milestone [^>]*unit="juan"\/>)/, '\2\1')

    doc = Nokogiri::XML(s)
    doc.remove_namespaces!()
    doc
  end

  def read_mod_notes(doc)
    doc.xpath("//note[@type='mod']").each { |e|
      @mod_notes << e['n']
    }
  end

  def parse_xml(xml_fn)
    @pass = [false]

    doc = open_xml(xml_fn)
    
    e = doc.xpath("//titleStmt/title")[0]
    @title = traverse(e, 'txt')
    @title = @title.split()[-1]
    
    read_mod_notes(doc)

    root = doc.root()
    body = root.xpath("text/body")[0]
    @pass = [true]

    text = traverse(body)
    text
  end

  def traverse(e, mode='html')
    r = ''
    e.children.each { |c| 
      s = handle_node(c, mode)
      r += s
    }
    r
  end

end