require 'cgi'
require 'fileutils'
require 'json'
require 'nokogiri'
require 'set'

# Convert CBETA XML P5a to simple HTML
#
# CBETA XML P5a 可由此取得: https://github.com/cbeta-git/xml-p5a
#
# @example for convert 大正藏第一冊:
#
#   c = CBETA::P5aToSimpleHTML.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
#   c.convert('T01')
#
class CBETA::P5aToSimpleHTML

  # @param xml_root [String] 來源 CBETA XML P5a 路徑
  # @param output_root [String] 輸出 Text 路徑
  def initialize(xml_root, output_root)
    @xml_root = xml_root
    @output_root = output_root
    @cbeta = CBETA.new
    @gaijis = CBETA::Gaiji.new
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

  def handle_g(e)
    # if 悉曇字、蘭札體
    #   使用 Unicode PUA
    # else if 有 <mapping type="unicode">
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
    
    if gid.start_with?('SD') # 悉曇字
      case gid
      when 'SD-E35A'
        return '（'
      when 'SD-E35B'
        return '）'
      else
        return CBETA.siddham_pua(gid)
      end
    end
    
    if gid.start_with? 'RJ' # 蘭札體
      return CBETA.ranjana_pua(gid)
    end
    
    return g['unicode-char'] if g.has_key?('unicode')
    return g['normal_unicode'] if g.has_key?('normal_unicode')
    return g['normal'] if g.has_key?('normal')

    # Unicode PUA
    [0xf0000 + gid[2..-1].to_i].pack 'U'
  end

  def handle_lb(e)
    r = "<a id='lb#{e['n']}'/>"
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

  def handle_milestone(e)
    r = ''
    if e['unit'] == 'juan'
      @juan = e['n'].to_i
      r += "<juan #{@juan}>"
    end
    r
  end

  def handle_node(e)
    return '' if e.comment?
    return handle_text(e) if e.text?
    return '' if PASS.include?(e.name)
    r = case e.name
    when 'anchor'    then handle_anchor(e)
    when 'back'      then ''
    when 'corr'      then handle_corr(e)
    when 'foreign'   then ''
    when 'g'         then handle_g(e)
    when 'graphic'   then ''
    when 'lb'        then handle_lb(e)
    when 'lem'       then handle_lem(e)
    when 'mulu'      then ''
    when 'note'      then handle_note(e)
    when 'milestone' then handle_milestone(e)
    when 'rdg'       then handle_rdg(e)
    when 'reg'       then ''
    when 'sic'       then handle_sic(e)
    when 'sg'        then handle_sg(e)
    when 'tt'        then handle_tt(e)
    when 't'         then handle_t(e)
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

  def handle_rdg(e)
    r = traverse(e)
    w = e['wit'].scan(/【.*?】/)
    @editions.merge w
    "<r w='#{e['wit']}'>#{r}</r>"
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

    # 不是雙行對照
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

  def handle_text(e)
    s = e.content().chomp
    return '' if s.empty?
    return '' if e.parent.name == 'app'

    # cbeta xml 文字之間會有多餘的換行
    r = s.gsub(/[\n\r]/, '')

    # 把 & 轉為 &amp;
    CGI.escapeHTML(r)
  end

  def handle_tt(e)
    @tt_type = e['type']
    traverse(e)
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
    folder = File.join(@out_sutra, "%03d" % juan_no)
    FileUtils.makedirs(folder)
    @editions.each do |ed|
      frag = Nokogiri::XML.fragment(txt)
      frag.search("r").each do |node|
        if node['w'] == ed
          node.add_previous_sibling(node.text)
        end
        node.remove
      end

      text = <<-END.gsub(/^\s+\|/, '')
        |<!DOCTYPE html>
        |<html>
        |<head>
        |  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        |</head>
        |<body>
      END
      text += to_html(frag) + "</body></html>"

      fn = ed.sub(/^【(.*?)】$/, '\1')
      fn = "#{fn}.html"
      output_path = File.join(folder, fn)
      File.write(output_path, text)
    end
  end

  def to_html(e)
    e.to_xml(encoding: 'UTF-8', :save_with => Nokogiri::XML::Node::SaveOptions::AS_XML)
  end
end