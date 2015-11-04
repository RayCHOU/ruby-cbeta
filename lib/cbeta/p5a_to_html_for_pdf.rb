require 'cgi'
require 'date'
require 'fileutils'
require 'json'
require 'nokogiri'
require 'set'

# Convert CBETA XML P5a to HTML for PDF
#
# You can get CBETA XML P5a from: https://github.com/cbeta-git/xml-p5a
class CBETA::P5aToHTMLForPDF
  # 內容不輸出的元素
  PASS=['back', 'teiHeader']

  # 某版用字缺的符號
  MISSING = '－'
  
  private_constant :PASS, :MISSING

  # @param xml_root [String] 來源 CBETA XML P5a 路徑
  # @param out_root [String] 輸出 HTML 路徑
  # @option opts [String] :graphic_base folder of graphics
  #   * graphic_base/figures: 插圖圖檔位置
  #   * graphic_base/sd-gif: images for Siddham (悉曇字)
  #   * graphic_base/rj-gif: images for Ranjana (蘭札體)
  def initialize(xml_root, out_root, opts={})
    @config = {
    }
    @config.merge!(opts)
    
    @xml_root = xml_root
    @out_root = out_root
    @cbeta = CBETA.new
    @gaijis = CBETA::Gaiji.new
  end

  # 將 CBETA XML P5a 轉為 HTML 供轉為 PDF
  #
  # @example for convert 大正藏第一冊:
  #
  #   c = CBETA::P5aToHTMLForPDF.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
  #   c.convert('T01')
  #
  # @example for convert 大正藏全部:
  #
  #   c = CBETA::P5aToHTMLForPDF.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
  #   c.convert('T')
  #
  # @example for convert 大正藏第五冊至第七冊:
  #
  #   c = CBETA::P5aToHTMLForPDF.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
  #   c.convert('T05..T07')
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

  def convert_all
    Dir.foreach(@xml_root) { |c|
      next unless c.match(/^[A-Z]$/)
      handle_collection(c)
    }
  end

  def handle_anchor(e)
    id = e['id']

    if e.has_attribute?('type')
      if e['type'] == 'circle'
        return '◎'
      end
    end

    ''
  end

  def handle_app(e)
    traverse(e)
  end

  def handle_byline(e)
    s = traverse(e)
    "<p class='byline'>#{s}</p>"
  end

  def handle_cell(e)
    doc = Nokogiri::XML::Document.new
    cell = doc.create_element('td')
    cell['rowspan'] = e['rows'] if e.key? 'rows'
    cell['colspan'] = e['cols'] if e.key? 'cols'
    cell.inner_html = traverse(e)
    to_html(cell)
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
    traverse(e)
  end

  def handle_div(e)
    if e.has_attribute? 'type'
      @open_divs << e
      r = traverse(e)
      @open_divs.pop
      return "<div>#{r}</div>"
    else
      return traverse(e)
    end
  end

  def handle_figure(e)
    "<div class='figure'>%s</div>" % traverse(e)
  end

  def handle_g(e, mode)
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
        fn = "#{gid}.gif"
        src = File.join(@config[:graphic_base], 'sd-gif', gid[3..4], fn)
        dest = File.join(@output_folder_sutra, fn)
        FileUtils.copy(src, dest)
        return "<img src='#{fn}'/>"
      end
    end
    
    if gid.start_with?('RJ')
      fn = "#{gid}.gif"
      src = File.join(@config[:graphic_base], 'rj-gif', gid[3..4], fn)
      dest = File.join(@output_folder_sutra, fn)
      return "<img src='#{fn}'/>"
    end
   
    if g.has_key?('unicode')
      if @unicode1.include?(g['unicode'])
        return g['unicode-char'] # 直接採用 unicode
      end
    end

    return g['normal_unicode'] if g.has_key?('normal_unicode')
    return g['normal'] if g.has_key?('normal')

    zzs
  end

  def handle_graphic(e)
    url = e['url']
    url.sub!(/^.*(figures\/.*)$/, '\1')
    
    src = File.join(@config[:graphic_base], url)
    fn = File.basename(src)
    dest = File.join(@output_folder_sutra, fn)
    FileUtils.copy(src, dest)
    "<img src='#{fn}'/>"
  end

  def handle_head(e)
    if e['type'] == 'added'
      return ''
    elsif e.parent.name == 'list'
      return traverse(e)
    else
      i = @open_divs.size
      return "<p class='h#{i}'>%s</p>" % traverse(e)
    end
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
    r = to_html(cell)
    
    unless @lg_row_open
      r = "\n<div class='lg-row'>" + r
      @lg_row_open = true
    end
    @in_l = false
    r
  end

  def handle_lb(e)
    # 卍續藏有 X 跟 R 兩種 lb, 只處理 X
    return '' if e['ed'] != @series
    
    r = ''
    if @lg_row_open && !@in_l
      # 每行偈頌放在一個 lg-row 裡面
      # T46n1937, p. 914a01, l 包雙行夾註跨行
      # T20n1092, 337c16, lb 在 l 中間，不結束 lg-row
      r += "</div><!-- end of lg-row -->"
      @lg_row_open = false
    end
    unless @t_buf1.empty? and @t_buf2.empty?
      r += print_tt
    end
    r
  end

  def handle_lem(e)
    traverse(e)
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
      r = "\n" + to_html(node)
    end
    r
  end

  def handle_list(e)
    "<ul>%s</ul>" % traverse(e)
  end

  def handle_milestone(e)
    ''
  end

  def handle_mulu(e)
    ''
  end

  def handle_node(e, mode)
    return '' if e.comment?
    return handle_text(e, mode) if e.text?
    return '' if PASS.include?(e.name)
    r = case e.name
    when 'anchor'    then handle_anchor(e)
    when 'app'       then handle_app(e)
    when 'byline'    then handle_byline(e)
    when 'cell'      then handle_cell(e)
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
    when 'row'       then handle_row(e)
    when 'sic'       then ''
    when 'sg'        then handle_sg(e)
    when 't'         then handle_t(e)
    when 'tt'        then handle_tt(e)
    when 'table'     then handle_table(e)
    else traverse(e)
    end
    r
  end

  def handle_note(e)
    n = e['n']
    if e.has_attribute?('type')
      t = e['type']
      if %w(equivalent orig orig_biao orig_ke mod rest).include? t
        return ''
      end
      return '' if t.start_with?('cf')
    end

    if e.has_attribute?('resp')
      return '' if e['resp'].start_with? 'CBETA'
    end

    r = traverse(e)
    if e.has_attribute?('place')
      if e['place']=='inline'
        r = "(#{r})"
      elsif e['place']=='interlinear'
        r = "(#{r})"
      end
    end
    r
  end

  def handle_p(e)
    "<p>%s</p>\n" % traverse(e)
  end

  def handle_row(e)
    "<tr>" + traverse(e) + "</tr>\n"
  end

  def handle_sg(e)
    '(' + traverse(e) + ')'
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
    @t_buf1 = []
    @t_buf2 = []
    @open_divs = []
    @sutra_no = File.basename(xml_fn, ".xml")
    
    @output_folder_sutra = File.join(@out_folder, @sutra_no)
    FileUtils.mkdir_p(@output_folder_sutra) unless Dir.exist? @output_folder_sutra
    
    src = File.join(CBETA::DATA, 'html-for-pdf.css')
    dest = File.join(@output_folder_sutra, 'html-for-pdf.css')
    FileUtils.copy(src, dest)

    text = parse_xml(xml_fn)
    text = "
<html>
<head>
  <meta http-equiv='Content-Type' content='text/html; charset=utf-8' />
  <link rel=stylesheet type='text/css' href='html-for-pdf.css'>
</head>
<body>#{text}</body>
</html>"

    fn = File.join(@output_folder_sutra, 'main.htm')
    File.write(fn, text)
  end

  def handle_t(e)
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
      @t_buf1 << r
    when 1
      @t_buf2 << r
    else
      return r
    end
    ''
  end

  def handle_tt(e)
    @tt_type = e['type']
    traverse(e)
  end

  def handle_table(e)
    "<table>" + traverse(e) + "</table>\n"
  end

  def handle_text(e, mode)
    s = e.content().chomp
    return '' if s.empty?
    return '' if e.parent.name == 'app'

    # cbeta xml 文字之間會有多餘的換行
    r = s.gsub(/[\n\r]/, '')

    # 把 & 轉為 &amp;
    r = CGI.escapeHTML(r)

    r
  end

  def handle_vol(vol)
    puts "convert volumn: #{vol}"

    @orig = @cbeta.get_canon_abbr(vol[0])
    abort "未處理底本" if @orig.nil?

    @vol = vol
    @series = vol[0]
    @out_folder = File.join(@out_root, @series, vol)
    FileUtils.remove_dir(@out_folder, force=true)
    FileUtils::mkdir_p @out_folder
    
    source = File.join(@xml_root, @series, vol)
    Dir.entries(source).sort.each { |f|
      next if f.start_with? '.'
      path = File.join(source, f)
      handle_sutra(path)
    }
  end

  def handle_vols(v1, v2)
    puts "convert volumns: #{v1}..#{v2}"
    @series = v1[0]
    folder = File.join(@xml_root, @series)
    Dir.foreach(folder) { |vol|
      next if vol < v1
      next if vol > v2
      handle_vol(vol)
    }
  end
  
  def open_xml(fn)
    s = File.read(fn)

    if fn.include? 'T16n0657'
      # 這個地方 雙行夾註 跨兩行偈頌
      # 把 lb 移到 note 結束之前
      # 讓 lg-row 先結束，再結束雙行夾註
      s.sub!(/(<\/note>)(\n<lb n="0206b29" ed="T"\/>)/, '\2\1')
    end

    doc = Nokogiri::XML(s)
    doc.remove_namespaces!()
    doc
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
    
    root = doc.root()
    body = root.xpath("text/body")[0]
    @pass = [true]

    text = traverse(body)
    text
  end
  
  def print_tt
    r = "<table class='tt'>\n"
    
    r += "<tr>\n"
    @t_buf1.each do |s|
      r += "<td>#{s}</td>"
    end
    r += "</tr>\n"
    
    r += "<tr>\n"
    @t_buf2.each do |s|
      r += "<td>#{s}</td>"
    end
    r += "</tr>\n"
    
    @t_buf1 = []
    @t_buf2 = []
    
    r + "<table>\n"
  end

  def to_html(e)
    e.to_xml(encoding: 'UTF-8', :save_with => Nokogiri::XML::Node::SaveOptions::AS_XML)
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