require 'cgi'
require 'date'
require 'fileutils'
require 'json'
require 'nokogiri'
require 'set'
require 'erb'
require_relative 'cbeta_share'

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
  # @option opts [String] :front_page 內文前可以加一段 HTML，例如「編輯說明」
  # @option opts [String] :front_page_title 加在目錄的 front_page 標題
  # @option opts [String] :back_page 內文後可以加一段 HTML，例如「版權聲明」
  # @option opts [String] :back_page_title 加在目錄的 back_page 標題
  # @option opts [Boolean] :toc 要不要放目次, 預設會有目次
  def initialize(xml_root, out_root, opts={})
    @config = {
      toc: true
    }
    @config.merge!(opts)
    
    @xml_root = xml_root
    @out_root = out_root
    @cbeta = CBETA.new
    @gaijis = CBETA::Gaiji.new
  end

  # 將 CBETA XML P5a 轉為 HTML 供轉為 PDF
  #
  # @example for convert 大正藏全部:
  #
  #   c = CBETA::P5aToHTMLForPDF.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
  #   c.convert('T')
  #
  # T 是大正藏的 ID, CBETA 的藏經 ID 系統請參考: http://www.cbeta.org/format/id.php
  def convert(target=nil)
    return convert_all if target.nil?

    arg = target.upcase
    convert_collection(arg)
  end

  private
  
  include CbetaShare
  
  def before_convert_work(work_id)
    @nav_doc = Nokogiri::XML('<ul></ul>')
    @nav_doc.remove_namespaces!()
    @nav_root = @nav_doc.at_xpath('/ul')
    @current_nav = [@nav_root]
    @div_count = 0
    @mulu_count = 0    
    @open_divs = []
    @text = ''
    
    @output_folder_work = File.join(@out_root, @series, work_id)
    FileUtils.mkdir_p(@output_folder_work) unless Dir.exist? @output_folder_work

    src = File.join(CBETA::DATA, 'html-for-pdf.css')
    copy_file(src)
    
    @cover = nil
    if @config.key? :graphic_base
      cover = File.join(@config[:graphic_base], 'covers', @series, "#{work_id}.jpg")
      if File.exist? cover
        @mulu_count += 1
        @cover = "<a id='mulu#{@mulu_count}'></a><mulu1 title='封面'>&nbsp;</mulu1>"
        @cover += "<div id='cover'><img src='#{work_id}.jpg' /></div>"
        copy_file(cover)
      end
    end
    
    if @config[:front_page_title]
      s = @config[:front_page_title]
      @nav_root.add_child("<li><a href='#front'>#{s}</a></li>")
    end
    
  end
  
  def before_parse_xml(xml_fn)
    @in_l = false
    @lg_row_open = false
    @t_buf1 = []
    @t_buf2 = []
    @sutra_no = File.basename(xml_fn, ".xml")
  end

  def convert_all
    Dir.foreach(@xml_root) { |c|
      next unless c.match(/^[A-Z]$/)
      convert_collection(c)
    }
  end
  
  def convert_collection(c)
    @series = c
    puts 'convert_collection ' + c
    
    @orig = @cbeta.get_canon_abbr(c)
    
    folder = File.join(@xml_root, @series)
    @works = {}
    prepare_work_list(folder)
    @works.each do |work_id, xml_files|
      convert_work(work_id, xml_files)
    end
  end
  
  def convert_work(work_id, xml_files)
    puts "convert xml to html: work_id: #{work_id}"
    
    before_convert_work(work_id)
    
    # 目次
    if @config[:back_page_title]
      s = @config[:back_page_title]
      @nav_root.add_child("<li><a href='#back'>#{s}</a></li>")
    end
    
    
    if @config.key? :front_page
      s = File.read(@config[:front_page])
      @front = "<div id='front'>#{s}</div>"
    end
    
    if @config.key? :back_page
      s = File.read(@config[:back_page])
      @back = "<div id='back'>#{s}</div>"
    end
    
    xml_files.each do |fn|
      @text += convert_xml_file(fn)
    end
    
    if @config[:toc]
      @toc = to_html(@nav_root)
      @toc.gsub!('<ul/>', '')
    	@toc = "<div><h1>目次</h1>#{@toc}</div>"
    else
      @toc = ''
    end

    fn = File.join(CBETA::DATA, 'pdf-template.htm')
    template = File.read(fn)
    output = template % {
      cover: @cover,
      toc: @toc,
      front: @front,
      text: @text,
      back: @back
    }

    fn = File.join(@output_folder_work, 'main.htm')
    File.write(fn, output)
  end
  
  def convert_xml_file(xml_fn)
    before_parse_xml(xml_fn)
    parse_xml(xml_fn)
  end
  
  def copy_file(src)
    basename = File.basename(src)
    dest = File.join(@output_folder_work, basename)
    FileUtils.copy(src, dest)    
  end

  def handle_anchor(e)
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


  def handle_corr(e)
    "<span class='corr'>%s</span>" % traverse(e)
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

  def handle_doc_number(e)
    "<p>%s</p>" % traverse(e)
  end
  
  def handle_figure(e)
    "<div class='figure'>%s</div>" % traverse(e)
  end

  def handle_g(e, mode)
    # 悉曇字、蘭札體 使用圖檔
    # 如果有對應的 unicode 且不在 Unicode Extension C, D, E 範圍裡，直接採用 unicode
    # 呈現組字式
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

    if gid.start_with?('SD')
      case gid
      when 'SD-E35A'
        return '（'
      when 'SD-E35B'
        return '）'
      else
        fn = "#{gid}.gif"
        src = File.join(@config[:graphic_base], 'sd-gif', gid[3..4], fn)
        copy_file(src)
        return "<img src='#{fn}'/>"
      end
    end
    
    if gid.start_with?('RJ')
      fn = "#{gid}.gif"
      src = File.join(@config[:graphic_base], 'rj-gif', gid[3..4], fn)
      copy_file(src)
      return "<img src='#{fn}'/>"
    end
   
    if g.has_key?('unicode')
      # 如果不在 unicode ext-C, ext-D, ext-E 範圍內
      unless (0x2A700..0x2CEAF).include? g['unicode'].hex
        return g['unicode-char'] # 直接採用 unicode
      end
    end

    zzs
  end

  def handle_graphic(e)
    url = e['url']
    url.sub!(/^.*(figures\/.*)$/, '\1')
    
    src = File.join(@config[:graphic_base], url)
    copy_file(src)
    
    fn = File.basename(src)
    "<img src='#{fn}'/>"
  end

  def handle_head(e)
    if e['type'] == 'added'
      return ''
    elsif e.parent.name == 'list'
      return traverse(e)
    else
      i = @open_divs.size
      if i <= 6
        return "<p class='h#{i}'>%s</p>" % traverse(e)
      else
        return "<p class='h#{i}'>%s</p>" % traverse(e)
      end
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
    cell.inner_html = traverse(e) + '　'
    
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

  def handle_lb(e)
    return '' if e['type']=='old'
    
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
    r = nil
    w = e['wit']
    if e.key? 'wit'
      if (w.include? 'CBETA') and (not w.include? @orig)
        r = "<span class='corr'>%s</span>" % traverse(e)
      end
    end
    r = traverse(e) if r.nil?
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
      r = "\n" + to_html(node)
    end
    r
  end

  def handle_list(e)
    doc = Nokogiri::XML::Document.new
    node = doc.create_element('ul')
    if e.key? 'rendition'
      node['class'] = e['rendition']
    end
    node.inner_html = traverse(e)
    to_html(node) + "\n"
  end

  def handle_milestone(e)
    ''
  end

  def handle_mulu(e)
    return '' if e['type']=='卷'
    @mulu_count += 1
    level = e['level'].to_i
    while @current_nav.size > level
      @current_nav.pop
    end
  
    label = traverse(e, 'txt')
    li = @current_nav.last.add_child("<li><a href='#mulu#{@mulu_count}'>#{label}</a></li>").first
    ul = li.add_child('<ul></ul>').first
    @current_nav << ul
    
    # mulu 標記裡要有東西，prince 才會產生 pdf bookmark
    "<a id='mulu#{@mulu_count}'></a><mulu#{level} title='#{label}'>&nbsp;</mulu#{level}>"
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
    when 'docNumber' then handle_doc_number(e)
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
    when 'unclear'   then handle_unclear(e)
    else traverse(e)
    end
    r
  end

  def handle_note(e)
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
    doc = Nokogiri::XML::Document.new
    node = doc.create_element('p')
    if e.key? 'rend'
      node['style'] = e['rend']
    end
    node.inner_html = traverse(e)
    to_html(node) + "\n"
  end

  def handle_row(e)
    "<tr>" + traverse(e) + "</tr>\n"
  end

  def handle_sg(e)
    '(' + traverse(e) + ')'
  end

  def handle_sutra(xml_fn)
    puts "convert sutra #{xml_fn}"
    
    before_parse_xml(xml_fn)

    @text = parse_xml(xml_fn)
    
    # 目次
    if @config[:back_page_title]
      s = @config[:back_page_title]
      @nav_root.add_child("<li><a href='#back'>#{s}</a></li>")
    end
    @toc = to_html(@nav_root)
    @toc.gsub!('<ul/>', '')
    
    if @config.key? :graphic_base
      
    end
    
    if @config.key? :front_page
      s = File.read(@config[:front_page])
      @front = "<div id='front'>#{s}</div>"
    end
    
    if @config.key? :back_page
      s = File.read(@config[:back_page])
      @back = "<div id='back'>#{s}</div>"
    end

    fn = File.join(CBETA::DATA, 'pdf-template.htm')
    template = File.read(fn)
    output = template % {
      title: @title,
      author: @author,
      toc: @toc,
      front: @front,
      text: @text,
      back: @back
    }

    fn = File.join(@output_folder_sutra, 'main.htm')
    File.write(fn, output)
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
  
  def handle_unclear(e)
    '▆'
  end

  def handle_vol(vol)
    puts "convert volumn: #{vol}"

    @orig = @cbeta.get_canon_abbr(vol[0])
    abort "未處理底本" if @orig.nil?
    puts "#{__LINE__} orig: #{@orig}"

    @vol = vol
    @series = CBETA.get_canon_from_vol(vol)
    @out_folder = File.join(@out_root, @series, vol)
    FileUtils.remove_dir(@out_folder, true)
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
    @series = CBETA.get_canon_from_vol(v1)
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
    
    @author = doc.at_xpath("//titleStmt/author").text
    
    if @cover.nil?
      @cover = "<p class='title'>#{@title}</p>\n"
      @cover += "<p class='author'>#{@author}</p>"
    end    
    
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
  
  def prepare_work_list(input_folder)
    Dir.foreach(input_folder) do |f|
      next if f.start_with? '.'
      p1 = File.join(input_folder, f)
      if File.file?(p1)
        work = f.sub(/^([A-Z]{1,2})\d{2,3}n(.*)\.xml$/, '\1\2')
        work = 'T0220' if work.start_with? 'T0220'
        unless @works.key? work
          @works[work] = []
        end
        @works[work] << p1
      else
        prepare_work_list(p1)
      end
    end
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