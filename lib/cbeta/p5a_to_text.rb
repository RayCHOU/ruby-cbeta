require 'cgi'
require 'date'
require 'fileutils'
require 'json'
require 'nokogiri'
require 'set'

# Convert CBETA XML P5a to Text
#
# CBETA XML P5a 可由此取得: https://github.com/cbeta-git/xml-p5a
#
# @example for convert 大正藏第一冊 in app format:
#
#   c = CBETA::P5aToText.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER', 'app')
#   c.convert('T01')
#
class CBETA::P5aToText
  # 內容不輸出的元素
  PASS=['back', 'teiHeader']
  
  private_constant :PASS

  # @param xml_root [String] 來源 CBETA XML P5a 路徑
  # @param output_root [String] 輸出 Text 路徑
  # @param format [String] 輸出格式，例：'app'
  # @option opts [String] :format 輸出格式，例：'app'，預設是 normal
  # @option opts [String] :encoding 輸出編碼，預設 'UTF-8'
  # @option opts [String] :gaiji 缺字處理方式，預設 'default'
  #   * 'PUA': 缺字一律使用 Unicode PUA
  #   * 'default': 優先使用通用字
  def initialize(xml_root, output_root, opts={})
    @xml_root = xml_root
    @output_root = output_root
    
    @settings = {
      format: nil,
      encoding: 'UTF-8',
      gaiji: 'default'
    }
    @settings.merge!(opts)
    
    @cbeta = CBETA.new
    @gaijis = CBETA::Gaiji.new
  end

  # 將 CBETA XML P5a 轉為 Text
  #
  # @example for convert all:
  #
  #   x2h = CBETA::P5aToText.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
  #   x2h.convert
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
    if arg.size <= 2
      handle_canon(arg)
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

  # 跨行字詞移到下一行
  def appify(text)
    r = ''
    i = 0
    app = ''
    text.each_line do |line|
      line.chomp!
      if line.match(/^(.*)║(.*)$/)
        r += $1
        t = $2
        r += "(%02d)" % i
        r += "║#{app}"
        app = ''
        i = 0
        chars = t.chars
        until chars.empty?
          c = chars.pop
          if c == "\t"
            break
          elsif ' 　：》」』、；，！？。'.include? c
            chars << c
            break
          elsif '《「『'.include? c  # 這些標點移到下一行
            app = c + app
            break
          else
            app = c + app
          end
        end
        r += chars.join.gsub(/\t/, '') + "\n"
        i = app.size
      end
    end
    r
  end

  def convert_all
    Dir.entries(@xml_root).sort.each do |c|
      next unless c.match(/^#{CBETA.CANON}$/)
      handle_canon(c)
    end
  end

  # 取得所有對校版本
  def get_editions(doc)
    r = Set.new [@orig, "【CBETA】"] # 至少有底本及 CBETA 兩個版本
    doc.xpath('//lem|//rdg').each do |e|
      w = e['wit'].scan(/【.*?】/)
      r.merge w
    end
    r
  end
  
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

  def e_byline(e)
    r = traverse(e)
    r += @settings[:format]=='app' ? "\t" : "\n"
    r
  end

  def e_cell(e)
    r = traverse(e)
    r += @settings[:format]=='app' ? "\t" : "\n"
    r
  end

  def e_corr(e)
    "<r w='【CBETA】'>%s</r>" % traverse(e)
  end

  def e_div(e)
    traverse(e)
  end

  def e_docNumber(e)
    r = traverse(e)
    r += @settings[:format] == 'app' ? "\t" : "\n"
    r
  end

  def e_figure(e)
    r = traverse(e)
    r += @settings[:format] == 'app' ? "\t" : "\n"
    r
  end

  def e_g(e)
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
    
    if @settings[:gaiji] == 'PUA'
      return CBETA.siddham_pua(gid) if gid.start_with?('SD') # 悉曇字
      return CBETA.ranjana_pua(gid) if gid.start_with?('RJ') # 蘭札體
      return CBETA.pua(gid)
    end
    
    g = @gaijis[gid]
    abort "Line:#{__LINE__} 無缺字資料:#{gid}" if g.nil?
    
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
    
    if gid.start_with?('RJ') # 蘭札體      
      return CBETA.ranjana_pua(gid)
    end
    
    return g['unicode-char'] if g.has_key?('unicode')
    return g['normal_unicode'] if g.has_key?('normal_unicode')
    return g['normal'] if g.has_key?('normal')

    # Unicode PUA
    [0xf0000 + gid[2..-1].to_i].pack 'U'
  end

  def e_graphic(e)
    ''
  end

  def e_head(e)
    r = traverse(e)
    r += @settings[:format] == 'app' ? "\t" : "\n"
    r
  end

  def e_item(e)
    r = traverse(e)
    r += @settings[:format] == 'app' ? "\t" : "\n"
  end

  def e_juan(e)
    r = traverse(e)
    r += @settings[:format] == 'app' ? "\t" : "\n"
    r
  end

  def e_l(e)
    r = traverse(e)
    if @settings[:format] == 'app'
      r += "\t"
    else
      r += "\n" unless @lg_type == 'abnormal'
    end
    r
  end

  def e_lb(e)
    r = ''
    if @settings[:format] == 'app'
      r += "\n#{e['n']}║"
    end
    unless @next_line_buf.empty?
      r += @next_line_buf + "\n"
      @next_line_buf = ''
    end
    r
  end

  def e_lem(e)
    # 沒有 rdg 的版本，用字同 lem
    editions = Set.new @editions
    e.xpath('./following-sibling::rdg').each do |rdg|
      rdg['wit'].scan(/【.*?】/).each do |w|
        editions.delete w
      end
    end
    
    w = editions.to_a.join(' ')
    "<r w='#{w}'>%s</r>" % traverse(e)
  end

  def e_lg(e)
    traverse(e)
  end

  def e_list(e)
    r = ''
    r += "\n" unless @settings[:format] == 'app'
    r + traverse(e)
  end

  def e_milestone(e)
    r = ''
    if e['unit'] == 'juan'
      @juan = e['n'].to_i
      r += "<juan #{@juan}>"
    end
    r
  end

  def e_mulu(e)
    ''
  end

  def e_note(e)
    if e.has_attribute?('place') && e['place']=='inline'
      r = traverse(e)
      return "（#{r}）"
    end
    ''
  end

  def e_p(e)
    r = traverse(e)
    r += @settings[:format] == 'app' ? "\t" : "\n"
    r
  end

  def e_rdg(e)
    "<r w='#{e['wit']}'>%s</r>" % traverse(e)
  end

  def e_row(e)
    traverse(e)
  end

  def e_sg(e)
    '(' + traverse(e) + ')'
  end

  def e_sic(e)
    "<r w='#{@orig}'>" + traverse(e) + "</r>"
  end

  def e_t(e)
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

  def e_table(e)
    traverse(e)
  end

  def handle_canon(c)
    @canon = c
    puts 'handle_canon ' + c
    folder = File.join(@xml_root, @canon)
    Dir.entries(folder).sort.each do |vol|
      next if vol.start_with? '.'
      handle_vol(vol)
    end
  end

  def handle_node(e)
    return '' if e.comment?
    return handle_text(e) if e.text?
    return '' if PASS.include?(e.name)
    r = case e.name
    when 'anchor'    then e_anchor(e)
    when 'app'       then e_app(e)
    when 'back'      then ''
    when 'byline'    then e_byline(e)
    when 'cell'      then e_cell(e)
    when 'corr'      then e_corr(e)
    when 'div'       then e_div(e)
    when 'docNumber' then e_docNumber(e)
    when 'figure'    then e_figure(e)
    when 'foreign'   then ''
    when 'g'         then e_g(e)
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
    when 'rdg'       then e_rdg(e)
    when 'reg'       then ''
    when 'row'       then e_row(e)
    when 'sic'       then e_sic(e)
    when 'sg'        then e_sg(e)
    when 'tt'        then e_tt(e)
    when 't'         then e_t(e)
    when 'table'     then e_table(e)
    when 'teiHeader' then ''
    when 'unclear'   then '▆'
    else traverse(e)
    end
    r
  end

  def handle_sutra(xml_fn)
    puts "convert sutra #{xml_fn}"
    @dila_note = 0
    @div_count = 0
    #@editions = Set.new [@orig, "【CBETA】"] # 至少有底本跟CBETA兩種版本
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
    juan_no = nil
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

  def handle_text(e)
    s = e.content().chomp
    return '' if s.empty?
    return '' if e.parent.name == 'app'

    # cbeta xml 文字之間會有多餘的換行
    r = s.gsub(/[\n\r]/, '')

    # 把 & 轉為 &amp;
    CGI.escapeHTML(r)
  end

  def e_tt(e)
    @tt_type = e['type']
    traverse(e)
  end

  def handle_vol(vol)
    puts "convert volumn: #{vol}"

    @canon = CBETA.get_canon_from_vol(vol)
    @orig = @cbeta.get_canon_symbol(@canon)
    abort "未處理底本" if @orig.nil?

    @vol = vol
    @out_vol = File.join(@output_root, @canon, vol)
    FileUtils.remove_dir(@out_vol, true)
    FileUtils.makedirs @out_vol
    
    source = File.join(@xml_root, @canon, vol)
    Dir.entries(source).sort.each { |f|
      next if f.start_with? '.'
      fn = File.join(source, f)
      handle_sutra(fn)
    }
  end

  def handle_vols(v1, v2)
    puts "convert volumns: #{v1}..#{v2}"
    @canon = get_canon_from_vol(v1)
    folder = File.join(@xml_root, @canon)
    Dir.entries(folder).sort.each do |vol|
      next if vol < v1
      next if vol > v2
      handle_vol(vol)
    end
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
    
    @editions = get_editions(doc)

    body = root.xpath("text/body")[0]
    traverse(body)
  end

  def traverse(e)
    r = ''
    e.children.each { |c| 
      s = handle_node(c)
      puts "handle_node return nil, node: " + c.to_s if s.nil?
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
        if node['w'].include? ed
          node.add_previous_sibling node.inner_html
        end
        node.remove
      end
      text = frag.content
      text = appify(text) if @settings[:format] == 'app'

      ed2 = ed.sub(/^【(.*?)】$/, '\1')
      if ed == @orig
        fn = "#{ed2}-orig.txt"
      else
        unless ed2 == 'CBETA'
          ed2 = @orig.sub(/^【(.*?)】$/, '\1') + '→' + ed2
        end
        fn = "#{ed2}.txt"
      end
      output_path = File.join(folder, fn)
      fo = File.open(output_path, 'w', encoding: @settings[:encoding])
      fo.write(text)
      fo.close
    end
  end
end