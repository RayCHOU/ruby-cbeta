require 'cgi'
require 'date'
require 'fileutils'
require 'json'
require 'nokogiri'
require 'set'

# Convert CBETA XML P5a to Text
#
# CBETA XML P5a 可由此取得: https://github.com/cbeta-git/xml-p5a
class CBETA::P5aToText

  # @param xml_root [String] 來源 CBETA XML P5a 路徑
  # @param output_root [String] 輸出 Text 路徑
  def initialize(xml_root, output_root)
    @xml_root = xml_root
    @output_root = output_root
    @cbeta = CBETA.new
    @gaijis = CBETA::Gaiji.new

    # 載入 unicode 1.1 字集列表
    fn = File.join(File.dirname(__FILE__), 'unicode-1.1.json')
    json = File.read(fn)
    @unicode1 = JSON.parse(json)
  end

  # 將 CBETA XML P5a 轉為 Text
  #
  # @example for convert 大正藏第一冊:
  #
  #   x2h = CBETA::P5aToText.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
  #   x2h.convert('T01')
  #
  # @example for convert 大正藏全部:
  #
  #   x2h = CBETA::P5aToText.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
  #   x2h.convert('T')
  #
  # @example for convert 大正藏第五冊至第七冊:
  #
  #   x2h = CBETA::P5aToText.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
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

  def convert_all
    Dir.foreach(@xml_root) { |c|
      next unless c.match(/^[A-Z]$/)
      handle_collection(c)
    }
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
    traverse(e) + "\n"
  end

  def handle_cell(e)
    traverse(e) + "\n"
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
    "<r w='【CBETA】'>%s</r>" % traverse(e)
  end

  def handle_div(e)
    traverse(e)
  end

  def handle_docNumber(e)
    traverse(e) + "\n"
  end

  def handle_figure(e)
    traverse(e) + "\n"
  end

  def handle_g(e)
    # if 有 <mapping type="unicode">
    #   直接採用
    # else if 有 <mapping type="normal_unicode">
    #   採用 normal_unicode
    # else if 有 normalized form
    #   採用 normalized form
    # else
    #   Unicode PUA
    gid = e['ref'][1..-1]
    g = @gaijis[gid]
    abort "Line:#{__LINE__} 無缺字資料:#{gid}" if g.nil?
    zzs = g['zzs']
    
    if gid.start_with?('SD')
      case gid
      when 'SD-E35A'
        return '（'
      when 'SD-E35B'
        return '）'
      else
        return g['roman']
      end
    end
    
    return g['roman'] if gid.start_with?('RJ')
    return g['unicode-char'] if g.has_key?('unicode')
    return g['normal_unicode'] if g.has_key?('normal_unicode')
    return g['normal'] if g.has_key?('normal')

    # Unicode PUA
    [0xf0000 + gid[2..-1].to_i].pack 'U'
  end

  def handle_graphic(e)
    ''
  end

  def handle_head(e)
    traverse(e) + "\n"
  end

  def handle_item(e)
    traverse(e) + "\n"
  end

  def handle_juan(e)
    traverse(e) + "\n"
  end

  def handle_l(e)
    r = traverse(e)
    unless @lg_type == 'abnormal'
      r += "\n"
    end
    r
  end

  def handle_lb(e)
    r = ''
    unless @next_line_buf.empty?
      r += @next_line_buf + "\n"
      @next_line_buf = ''
    end
    r
  end

  def handle_lem(e)
    r = ''
    r = traverse(e)
    w = e['wit'].scan(/【.*?】/)
    @editions.merge w
    w = w.join(' ')
    "<r w='#{w}'>#{r}</r>"
  end

  def handle_lg(e)
    traverse(e)
  end

  def handle_list(e)
    "\n" + traverse(e)
  end

  def handle_milestone(e)
    r = ''
    if e['unit'] == 'juan'
      @juan = e['n'].to_i
      r += "<juan #{@juan}>"
    end
    r
  end

  def handle_mulu(e)
    ''
  end

  def handle_node(e)
    return '' if e.comment?
    return handle_text(e) if e.text?
    return '' if PASS.include?(e.name)
    r = case e.name
    when 'anchor'    then handle_anchor(e)
    when 'app'       then handle_app(e)
    when 'back'      then ''
    when 'byline'    then handle_byline(e)
    when 'cell'      then handle_cell(e)
    when 'corr'      then handle_corr(e)
    when 'div'       then handle_div(e)
    when 'docNumber' then handle_docNumber(e)
    when 'figure'    then handle_figure(e)
    when 'foreign'   then ''
    when 'g'         then handle_g(e)
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
    when 'rdg'       then handle_rdg(e)
    when 'reg'       then ''
    when 'row'       then handle_row(e)
    when 'sic'       then handle_sic(e)
    when 'sg'        then handle_sg(e)
    when 't'         then handle_t(e)
    when 'table'     then handle_table(e)
    when 'teiHeader' then ''
    else traverse(e)
    end
    r
  end

  def handle_note(e)
    if e.has_attribute?('place') && e['place']=='inline'
      r = traverse(e)
      return "（#{r}）"
    end
    ''
  end

  def handle_p(e)
    traverse(e) + "\n"
  end

  def handle_rdg(e)
    r = traverse(e)
    w = e['wit'].scan(/【.*?】/)
    @editions.merge w
    "<r w='#{e['wit']}'>#{r}</r>"
  end

  def handle_row(e)
    traverse(e)
  end

  def handle_sg(e)
    '(' + traverse(e) + ')'
  end

  def handle_sic(e)
    "<r w='#{@orig}'>" + traverse(e) + "</r>"
  end

  def handle_sutra(xml_fn)
    puts "convert sutra #{xml_fn}"
    @dila_note = 0
    @div_count = 0
    @editions = Set.new ["【CBETA】"]
    @in_l = false
    @juan = 0
    @lg_row_open = false
    @mod_notes = Set.new
    @next_line_buf = ''
    @open_divs = []
    @sutra_no = File.basename(xml_fn, ".xml")

    text = parse_xml(xml_fn)
   
    # 大正藏 No. 220 大般若經跨冊，CBETA 分成多檔並在檔尾加上 a, b, c....
    # 輸出時去掉這些檔尾的 a, b, b....
    if @sutra_no.match(/^(T05|T06|T07)n0220/)
      @sutra_no = "#{$1}n0220"
    end

    @out_sutra = File.join(@out_vol, @sutra_no)
    FileUtils.makedirs @out_sutra

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
      else
        if juan_no.nil?
          buf = j
        else
          write_juan(juan_no, buf+j)
          buf = ''
        end
      end
    }
  end

  def handle_t(e)
    if e.has_attribute? 'place'
      return '' if e['place'].include? 'foot'
    end
    r = traverse(e)

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

  def handle_table(e)
    traverse(e)
  end

  def handle_text(e)
    s = e.content().chomp
    return '' if s.empty?
    return '' if e.parent.name == 'app'

    # cbeta xml 文字之間會有多餘的換行
    r = s.gsub(/[\n\r]/, '')

    # 把 & 轉為 &amp;
    CGI.escapeHTML(r)
  end

  def handle_vol(vol)
    puts "convert volumn: #{vol}"

    @orig = @cbeta.get_canon_abbr(vol[0])
    abort "未處理底本" if @orig.nil?

    @vol = vol
    @series = vol[0]
    @out_vol = File.join(@output_root, @series, vol)
    FileUtils.remove_dir(@out_vol, force=true)
    FileUtils.makedirs @out_vol
    
    source = File.join(@xml_root, @series, vol)
    Dir[source+"/*"].each { |f|
      handle_sutra(f)
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
    doc = Nokogiri::XML(s)
    doc.remove_namespaces!()
    doc
  end

  def parse_xml(xml_fn)
    doc = open_xml(xml_fn)        
    root = doc.root()

    body = root.xpath("text/body")[0]
    traverse(body)
  end

  def traverse(e)
    r = ''
    e.children.each { |c| 
      s = handle_node(c)
      r += s
    }
    r
  end

  def write_juan(juan_no, txt)
    @editions.each do |ed|
      frag = Nokogiri::XML.fragment(txt)
      frag.search("r").each do |node|
        if node['w'] != ed
          node.remove
        end
      end

      folder = File.join(@out_sutra, ed)
      FileUtils.makedirs(folder)

      fn = "#{@sutra_no}_%03d.txt" % juan_no
      output_path = File.join(folder, fn)
      File.write(output_path, frag.content)
    end
  end
end