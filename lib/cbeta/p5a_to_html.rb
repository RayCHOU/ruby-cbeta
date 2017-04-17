require 'cgi'
require 'date'
require 'fileutils'
require 'json'
require 'nokogiri'
require 'set'
require_relative 'cbeta_share'

# Convert CBETA XML P5a to HTML
#
# CBETA XML P5a 可由此取得: https://github.com/cbeta-git/xml-p5a
#
# 轉檔規則請參考: http://wiki.ddbc.edu.tw/pages/CBETA_XML_P5a_轉_HTML
class CBETA::P5aToHTML
  # 內容不輸出的元素
  PASS=['back', 'teiHeader']

  # 某版用字缺的符號
  MISSING = '－'
  
  private_constant :PASS, :MISSING

  # @param xml_root [String] 來源 CBETA XML P5a 路徑
  # @param out_root [String] 輸出 HTML 路徑
  def initialize(xml_root, out_root)
    @xml_root = xml_root
    @out_root = out_root
    @cbeta = CBETA.new
    @gaijis = CBETA::Gaiji.new
  end

  # 將 CBETA XML P5a 轉為 HTML
  #
  # @example for convert 大正藏第一冊:
  #
  #   x2h = CBETA::P5aToHTML.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
  #   x2h.convert('T01')
  #
  # @example for convert 大正藏全部:
  #
  #   x2h = CBETA::P5aToHTML.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
  #   x2h.convert('T')
  #
  # @example for convert 大正藏第五冊至第七冊:
  #
  #   x2h = CBETA::P5aToHTML.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
  #   x2h.convert('T05..T07')
  #
  # T 是大正藏的 ID, CBETA 的藏經 ID 系統請參考: http://www.cbeta.org/format/id.php
  def convert(target=nil)
    return convert_all if target.nil?

    arg = target.upcase
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
  
  include CbetaShare

  def convert_all
    Dir.foreach(@xml_root) { |c|
      next unless c.match(/^[A-Z]$/)
      handle_collection(c)
    }
  end

  def e_anchor(e)
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

  def e_app(e)
    r = ''
    if e['type'] == 'star'
      c = e['corresp'][1..-1]
      r = "<a class='noteAnchor star' href='#n#{c}'></a>"
    end
    r + traverse(e)
  end

  def e_byline(e)
    r = '<p class="byline">'
    r += "<span class='lineInfo' line='#{@lb}'></span>"
    r += traverse(e)
    r + '</p>'
  end

  def e_cell(e)
    doc = Nokogiri::XML::Document.new
    cell = doc.create_element('div')
    cell['class'] = 'bip-table-cell'
    cell['rowspan'] = e['rows'] if e.key? 'rows'
    cell['colspan'] = e['cols'] if e.key? 'cols'
    cell.inner_html = traverse(e)
    to_html(cell)
  end

  def e_corr(e)
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

  def e_div(e)
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

  def e_figure(e)
    "<p class='figure'>%s</p>" % traverse(e)
  end

  def e_g(e, mode)
    # if 有 <mapping type="unicode">
    #   if 不在 Unicode Extension C, D, E 範圍裡
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
      #if @unicode1.include?(g['unicode'])
      # 如果在 unicode ext-C, ext-D, ext-E 範圍內
      if (0x2A700..0x2CEAF).include? g['unicode'].hex
        default = g['unicode-char']
      else
        return g['unicode-char'] # 直接採用 unicode
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

  def e_graphic(e)
    url = File.basename(e['url'])
    "<span imgsrc='#{url}' class='graphic'></span>"
  end

  def e_head(e)
    r = ''
    unless e['type'] == 'added'
      i = @open_divs.size
      r = "<p class='head' data-head-level='#{i}'>%s</p>" % traverse(e)
    end
    r
  end

  def e_item(e)
    "<li>%s</li>\n" % traverse(e)
  end

  def e_juan(e)
    "<p class='juan'>%s</p>" % traverse(e)
  end

  def e_l(e)
    if @lg_type == 'abnormal'
      return traverse(e)
    end

    @in_l = true

    doc = Nokogiri::XML::Document.new
    cell = doc.create_element('div')
    cell['class'] = 'lg-cell'
    cell.inner_html = traverse(e)
    
    if e.key? 'rend'
      cell['style'] = e['rend']
    elsif @first_l
      parent = e.parent()
      if parent.has_attribute?('rend')
        indent = parent['rend'].scan(/text-indent:[^:]*/)
        unless indent.empty?
          cell['style'] = indent[0]
        end
      end
    end
    @first_l = false
    
    r = to_html(cell)
    
    unless @lg_row_open
      r = "\n<div class='lg-row'>" + r
      @lg_row_open = true
    end
    @in_l = false
    r
  end

  def e_lb(e)
    # 卍續藏有 X 跟 R 兩種 lb, 只處理 X
    return '' if e['ed'] != @series

    @char_count = 1
    @lb = e['n']
    line_head = CBETA.get_linehead(@sutra_no, @lb)
    
    r = ''
    #if e.parent.name == 'lg' and $lg_row_open
    if @lg_row_open && !@in_l
      # 每行偈頌放在一個 lg-row 裡面
      # T46n1937, p. 914a01, l 包雙行夾註跨行
      # T20n1092, 337c16, lb 在 l 中間，不結束 lg-row
      r += "</div><!-- end of lg-row -->"
      @lg_row_open = false
    end
    r += "<span class='lb' \nid='#{line_head}'>#{line_head}</span>"
    unless @next_line_buf.empty?
      r += @next_line_buf
      @next_line_buf = ''
    end
    r
  end

  def e_lem(e)
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

  def e_lg(e)
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
      r = "\n" + to_html(node)
    end
    r
  end

  def e_list(e)
    "<ul>%s</ul>" % traverse(e)
  end

  def e_milestone(e)
    r = ''
    if e['unit'] == 'juan'

      r += "</div>" * @open_divs.size  # 如果有 div 跨卷，要先結束, ex: T55n2154, p. 680a29, 跨 19, 20 兩卷
      @juan = e['n'].to_i
      @back[@juan] = @back[0]
      r += "<juan #{@juan}>"
      @open_divs.each { |d|
        r += "<div class='div-#{d['type']}'>"
      }
    end
    r
  end

  def e_mulu(e)
    r = ''
    if e['type'] == '品'
      @pass << false
      r = "<mulu class='pin' s='%s'/>" % traverse(e, 'txt')
      @pass.pop
    end
    r
  end
  
  def e_note(e)
    n = e['n']
    if e.has_attribute?('type')
      t = e['type']
      case t
      when 'equivalent'
        return ''
      when 'orig'
        return handle_note_orig(e)
      when 'orig_biao'
        return handle_note_orig(e, 'biao')
      when 'orig_ke'
        return handle_note_orig(e, 'ke')
      when 'mod'
        @pass << false
        s = traverse(e)
        @pass.pop
        @back[@juan] += "<span class='footnote cb' id='n#{n}'>#{s}</span>\n"
        return "<a class='noteAnchor cb' href='#n#{n}'></a>"
      when 'rest'
        return ''
      else
        return '' if t.start_with?('cf')
      end
    end

    if e.has_attribute?('resp')
      return '' if e['resp'].start_with? 'CBETA'
    end

    r = traverse(e)
    if e.has_attribute?('place')
      if e['place']=='inline'
        r = "<span class='doube-line-note'>#{r}</span>"
      elsif e['place']=='interlinear'
        r = "<span class='interlinear-note'>#{r}</span>"
      end
    end
    r
  end
  
  def e_p(e)
    if e.key? 'type'
      r = "<p class='%s'>" % e['type']
    else
      r = '<p>'
    end
    r += "<span class='lineInfo' line='#{@lb}'></span>"
    r += traverse(e)
    r + '</p>'
  end

  def e_row(e)
    "<div class='bip-table-row'>" + traverse(e) + "</div>"
  end

  def e_sg(e)
    '(' + traverse(e) + ')'
  end
  
  def e_t(e)
    if e.has_attribute? 'place'
      return '' if e['place'].include? 'foot'
    end
    r = traverse(e)

    # <tt type="app"> 不是 悉漢雙行對照
    return r if @tt_type == 'app'

    # 處理雙行對照
    i = e.xpath('../t').index(e)
    case i
    when 0
      return r + '　'
    when 1
      @next_line_buf += r + '　'
      return ''
    else
      return r
    end
  end

  def e_tt(e)
    @tt_type = e['type']
    traverse(e)
  end

  def e_table(e)
    "<div class='bip-table'>" + traverse(e) + "</div>"
  end
  
  def e_unclear(e)
    '▆'
  end

  def handle_collection(c)
    @series = c
    puts 'handle_collection ' + c
    folder = File.join(@xml_root, @series)
    Dir.entries(folder).sort.each { |vol|
      next if ['.', '..', '.DS_Store'].include? vol
      handle_vol(vol)
    }
  end

  def handle_node(e, mode)
    return '' if e.comment?
    return handle_text(e, mode) if e.text?
    return '' if PASS.include?(e.name)
    r = case e.name
    when 'anchor'    then e_anchor(e)
    when 'app'       then e_app(e)
    when 'byline'    then e_byline(e)
    when 'cell'      then e_cell(e)
    when 'corr'      then e_corr(e)
    when 'div'       then e_div(e)
    when 'figure'    then e_figure(e)
    when 'foreign'   then ''
    when 'g'         then e_g(e, mode)
    when 'graphic'   then e_graphic(e)
    when 'head'      then e_head(e)
    when 'item'      then e_item(e)
    when 'juan'      then e_juan(e)
    when 'l'         then e_l(e)
    when 'lb'        then e_lb(e)
    when 'lem'       then e_lem(e)
    when 'lg'        then e_lg(e)
    when 'list'      then e_list(e)
    when 'mulu'      then e_mulu(e)
    when 'note'      then e_note(e)
    when 'milestone' then e_milestone(e)
    when 'p'         then e_p(e)
    when 'rdg'       then ''
    when 'reg'       then ''
    when 'row'       then e_row(e)
    when 'sic'       then ''
    when 'sg'        then e_sg(e)
    when 't'         then e_t(e)
    when 'tt'        then e_tt(e)
    when 'table'     then e_table(e)
    when 'unclear'   then e_unclear(e)
    else traverse(e)
    end
    r
  end

  def handle_note_orig(e, anchor_type=nil)
    n = e['n']
    @pass << false
    s = traverse(e)
    @pass.pop

    c = @series
    
    # 如果 CBETA 沒有修訂，就跟底本的註一樣
    c += " cb" unless @mod_notes.include? n
    
    @back[@juan] += "<span class='footnote #{c}' id='n#{n}'>#{s}</span>\n"
    
    label = case anchor_type
    when 'biao' then " data-label='標#{n[-2..-1]}'"
    when 'ke'   then " data-label='科#{n[-2..-1]}'"
    else ''
    end
    
    return "<a class='noteAnchor #{c}' href='#n#{n}'#{label}></a>"
  end

  def handle_sutra(xml_fn)
    puts "convert sutra #{xml_fn}"
    @back = { 0 => '' }
    @char_count = 1
    @dila_note = 0
    @div_count = 0
    @in_l = false
    @juan = 0
    @lg_row_open = false
    @mod_notes = Set.new
    @next_line_buf = ''
    @open_divs = []
    @sutra_no = File.basename(xml_fn, ".xml")
    
    if @sutra_no.match(/^(T05|T06|T07)n0220/)
      @sutra_no = "#{$1}n0220"
    end    

    text = parse_xml(xml_fn)

    # 註標移到 lg-cell 裡面，不然以 table 呈現 lg 會有問題
    text.gsub!(/(<a class='noteAnchor'[^>]*><\/a>)(<div class="lg-cell"[^>]*>)/, '\2\1')
    
    juans = text.split(/(<juan \d+>)/)
    juan_no = nil
    buf = ''
    # 一卷一檔
    juans.each { |j|
      if j =~ /<juan (\d+)>$/
        juan_no = $1.to_i
      elsif juan_no.nil?
        buf = j
      else
        write_juan(juan_no, buf+j)
      end
    }
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
    puts "convert volumn: #{vol}"

    @orig = @cbeta.get_canon_abbr(vol[0])
    abort "未處理底本" if @orig.nil?

    @vol = vol
    @series = CBETA.get_canon_from_vol(vol)
    @out_folder = File.join(@out_root, @series, vol)
    FileUtils.remove_dir(@out_folder, true)
    FileUtils::mkdir_p @out_folder
    
    source = File.join(@xml_root, @series, vol)
    Dir[source+"/*"].each { |f|
      handle_sutra(f)
    }
  end

  def handle_vols(v1, v2)
    puts "convert volumns: #{v1}..#{v2}"
    @series = CBETA.get_canon_from_vol(v1)
    folder = File.join(@xml_root, @series)
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
        s = n.content
        if linehead_exist_in_cbeta(s)
          s = "<span class='note_cf'>#{s}</span>"
        end
        refs << s
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
  
  def linehead_exist_in_cbeta(s)
    fn = CBETA.linehead_to_xml_file_path(s)
    return false if fn.nil?
    
    path = File.join(@xml_root, fn)
    File.exist? path
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
    s.gsub!(%r{((?:<pb [^>]+>\n?)?(?:<lb [^>]+>\n?)+)(<milestone [^>]*unit="juan"[^/>]*/>)}, '\2\1')

    begin
      doc = Nokogiri::XML(s) { |config| config.strict }
    rescue Nokogiri::XML::SyntaxError => e
      puts "XML parse error, file: #{fn}"
      puts e
      abort
    end
    doc.remove_namespaces!()
    doc
  end

  def read_mod_notes(doc)
    doc.xpath("//note[@type='mod']").each { |e|
      n = e['n']
      @mod_notes << n
      
      # 例 T01n0026_p0506b07, 原註標為 7, CBETA 修訂為 7a, 7b
      n.match(/[a-z]$/) {
        @mod_notes << n[0..-2]
      }
    }
  end

  def parse_xml(xml_fn)
    @pass = [false]

    doc = open_xml(xml_fn)
    
    e = doc.xpath("//titleStmt/title")[0]
    @title = traverse(e, 'txt')
    @title = @title.split()[-1]
    
    e = doc.at_xpath("//editionStmt/edition/date")
    abort "找不到版本日期" if e.nil?
    @edition_date = e.text.sub(/\$Date: (.*?) \$$/, '\1')
    
    e = doc.at_xpath("//projectDesc/p[@lang='zh']")
    abort "找不到貢獻者" if e.nil?
    @contributors = e.text
    
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
  
  def write_juan(juan_no, body)
    #if @sutra_no.match(/^(T05|T06|T07)n0220/)
    #  fn = "#{$1}n0220_%03d.htm" % juan_no
    #else
    #  fn = "#{@sutra_no}_%03d.htm" % juan_no
    #end
    fn = "#{@sutra_no}_%03d.htm" % juan_no
    
    html = <<eos
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta name="filename" content="#{fn}" />
<title>#{@title}</title>
</head>
<body>
<!-- 
來源 XML CBETA P5a: https://github.com/cbeta-org/xml-p5a.git
轉檔程式: https://rubygems.org/gems/cbeta #{Date.today}
說明文件: http://wiki.ddbc.edu.tw/pages/CBETA_XML_P5a_轉_HTML
-->
<div id='body'>
eos
    html += body + "\n</div><!-- end of div[@id='body'] -->\n"
    html += "<div id='back'>\n" + @back[juan_no] + "</div>\n"
    html += "<div id='cbeta-copyright'><p>\n"
    
    orig = @cbeta.get_canon_nickname(@series)
    v = @vol.sub(/^[A-Z]0*([^0].*)$/, '\1')
    n = @sutra_no.sub(/^[A-Z]\d{2,3}n0*([^0].*)$/, '\1')
    html += "【經文資訊】#{orig}第 #{v} 冊 No. #{n} #{@title}<br/>\n"
    html += "【版本記錄】CBETA 電子佛典 版本日期：#{@edition_date}<br/>\n"    
    html += "【編輯說明】本資料庫由中華電子佛典協會（CBETA）依#{orig}所編輯<br/>\n"
    
    html += "【原始資料】#{@contributors}<br/>\n"
    html += "【其他事項】本資料庫可自由免費流通，詳細內容請參閱【中華電子佛典協會資料庫版權宣告】\n"
    html += "</p></div><!-- end of cbeta-copyright -->\n"
    html += '</body></html>'
    
    output_path = File.join(@out_folder, fn)
    File.write(output_path, html)
  end

end