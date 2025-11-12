require_relative 'cbeta_share'

# 檢查 CBETA XML P5a
#
# * 錯誤類型
#   * [E01] 行號重複
#   * [E02] 文字直接出現在 div 下
#   * [E03] 星號校勘 app 沒有對應的 note
#   * [E04] rdg 缺少 wit 屬性"
#   * [E05] 圖檔 不存在
#   * [E06] lb format error
#   * [E07] lem 缺少 wit 屬性
#   * [E08] item 下有多個 list
#   * [E09] table cols 屬性值錯誤
#   * [E10] p 不應直接出現在 list 下
#   * [E11] note 直接出現在 div 下
#   * [E12] note 直接出現在 lg 下
#   * [E13] tt 直接出現在 lg 下
#   * [E14] <anchor type="right"> 不應直接出現在 div 或 body 下
#   * [E15] <note> corresp 無對應的 <note>
#
# * 警告類型
#   * [W01] 夾注包夾注
#   * [W02] 出現罕用字元
#   * [W03] 不應出現 TAB 字元
class CBETA::P5aChecker
  ALLOW_TAB = %w[change]

  # @param xml_root [String] 來源 CBETA XML P5a 路徑
  # @param figures [String] 插圖 路徑 (可由 https://github.com/cbeta-git/CBR2X-figures 取得)
  # @param log [String] Log file path
  def initialize(xml_root: nil, figures: nil, log: nil)
    @gaijis = CBETA::Gaiji.new
    @xml_root = xml_root
    @figures = figures
    @log = log
    @errors = []
    @g_errors = {}
  end
  
  # 檢查全部 CBETA XML P5a
  # @example 
  #   CBETA::P5aChecker.new(
  #     xml_root: '~/git-repos/cbeta-xml-p5a', 
  #     figures: '~/git-repos/CBR2X-figures', 
  #     log: '~/log/check-cbeta-xml.log'
  #   ).check
  def check
    puts "xml: #{@xml_root}"
    each_canon(@xml_root) do |c|
      @canon = c
      path = File.join(@xml_root, @canon)
      handle_canon(path)
    end

    display_errors
  end
  
  # 檢查某部藏經
  # @param canon [String] 藏經 ID, example: "T"
  def check_canon(canon)
    @canon = canon
    path = File.join(@xml_root, @canon)
    handle_canon(path)
    display_errors
  end

  # 檢查某一冊
  # @param vol [String] 冊號, example: "T01"
  def check_vol(vol)
    @vol = vol
    @canon = CBETA.get_canon_from_vol(vol)
    path = File.join(@xml_root, @canon, vol)
    handle_vol(path)
    display_errors
  end

  # 檢查單一檔案
  # @example 
  #   CBETA::P5aChecker.new(
  #     figures: '~/git-repos/CBR2X-figures',
  #     log: '~/log/check-cbeta-xml.log'
  #   ).check_file('~/git-repos/cbeta-xml-p5a/A/A110/A110n1490.xml')
  def check_file(fn)
    handle_file(fn)
    display_errors
  end

  private

  include CbetaShare

  def chk_text(node)
    return if node.text.strip.empty?
    
    if node.parent.name == 'div'
      error "[E02] 文字直接出現在 div 下, text: #{node.text.inspect}"
    end

    if node.text =~ /(\$|\{|\})/
      char = $1

      # 允許的已知用例：
      #   ZW07n0065_p0409a03：{本}續，大分為三。……初對辨題名者，梵云……，此云『吉
      if char == '{' and @basename == 'ZW07n0065.xml' and @lb == '0409a03'
        return
      end

      error "[W02] 出現罕用字元: char: #{char}"
    end

    if node.text.include?("\t")
      unless ALLOW_TAB.include?(node.parent.name)
        error "[W03] <#{node.parent.name}> 下不應出現 TAB 字元"
      end
    end
  end

  def display_errors
    @g_errors.keys.sort.each do |k|
      s = @g_errors[k].to_a.join(',')
      @errors << "#{k} 無缺字資料，出現於：#{s}"
    end
    
    if @errors.empty?
      puts "檢查完成，未發現錯誤。"
    elsif @log.nil?
      puts "發現 #{@errors.size} 錯誤："
      puts @errors.join("\n")
    else
      File.write(@log, @errors.join("\n"))
      puts "發現 #{@errors.size} 錯誤，請查看 #{@log}"
    end
  end

  def e_anchor(e)
    if e['type'] == "circle" and %w[body div].include?(e.parent.name)
      error %([E14] <anchor type="right"> 不應直接出現在 div 或 body 下)
    end
  end

  def e_app(e)
    if e['type'] == 'star'
      n = e['corresp'].delete_prefix('#')
      unless @notes.include?(n)
        error "[E03] 星號校勘 app 沒有對應的 note, corresp: #{n}"
      end
    end
    traverse(e)
  end

  def e_g(e)
    gid = e['ref'][1..-1]
    unless @gaijis.key? gid
      @g_errors[gid] = Set.new unless @g_errors.key? gid
      @g_errors[gid] << @basename
    end
  end
  
  def e_graphic(e)
    url = File.basename(e['url'])
    fn = File.join(@figures, @canon, url)
    unless File.exist? fn
      error "[E05] 圖檔 不存在, url: #{url}"
    end
  end

  def e_item(e)
    lists = e.xpath('list')
    if lists.size > 1
      error "[E08] item 下有多個 list"
    end
    traverse(e)
  end
  
  def e_lb(e)
    return if e['type']=='old'
    unless e['n'].match(/^[a-z\d]\d{3}[a-z]\d+$/)
      error "[E06] lb format error: #{e['n']}"
    end

    return if e['ed'] =~ /^R\d/

    @lb = e['n']
    ed_lb = "#{e['ed']}#{@lb}"
    if @lbs.include? ed_lb
      error "[E01] 行號重複, ed: #{e['ed']}"
    else
      @lbs << ed_lb
    end
  end
  
  def e_lem(e)
    unless e.key?('wit')
      error "[E07] lem 缺少 wit 屬性"
    end
    traverse(e)
  end

  def e_note(e)
    error "[E11] note 直接出現在 div 下" if e.parent.name == 'div'    
    error "[E12] note 直接出現在 lg 下" if e.parent.name == 'lg'
    e_note_corresp(e) if e.key?('corresp')

    unless e['place'] == 'inline'
      traverse(e)
      return 
    end

    if @element_stack.include?('inline_note')
      error "[W01] 夾注包夾注"
    end

    @element_stack << 'inline_note'
    traverse(e)
    @element_stack.pop
  end

  def e_note_corresp(e)
    n = e['corresp'].delete_prefix('#')
    return if @notes.include?(n)
    error "[E15] note corresp #{n} 無對應 note"
  end

  def e_p(e)
    if e.parent.name == 'list'
      error "[E10] p 不應直接出現在 list 下"
    end
    traverse(e)
  end

  def e_rdg(e)
    return if e['type'] == 'cbetaRemark'
    unless e.key?('wit')
      error "[E04] rdg 缺少 wit 屬性"
    end
  end

  def e_table(e)
    max_cols = 0
    e.xpath('row').each do |row|
      cols = 0
      row.xpath('cell').each do |cell|
        if cell.key?('cols')
          cols += cell['cols'].to_i
        else
          cols += 1
        end
      end
      max_cols = cols if cols > max_cols
    end

    if e['cols'].to_i != max_cols
      error "[E09] table cols 屬性值錯誤, table/@cols: #{e['cols']}, 根據 cell 計算的 cols: #{max_cols}"
    end

    traverse(e)
  end

  def e_tt(e)
    if e.parent.name == 'lg'
      error "[E13] tt 直接出現在 lg 下"
    end
    traverse(e)
  end

  def error(msg)
    s = "#{msg}, #{@basename}, lb: #{@lb}"
    puts "\n#{s}"
    @errors << s
  end
  
  def handle_canon(folder)
    Dir.entries(folder).sort.each do |f|
      next if f.start_with? '.'
      @vol = f
      path = File.join(folder, @vol)
      handle_vol(path)
    end
  end
  
  def handle_file(fn)
    @basename = File.basename(fn)
    @canon ||= CBETA.get_canon_id_from_linehead(@basename)

    s = File.read(fn)
    if s.include? "\u200B"
      @errors << "#{@basename} 含有 U+200B Zero Width Space 字元"
    end
    
    doc = Nokogiri::XML(s)
    if doc.errors.empty?
      doc.remove_namespaces!
      @lbs = Set.new
      read_notes(doc)
      @element_stack = []
      traverse(doc.root)
    else
      @errors << "錯誤: #{@basename} not well-formed"
    end
  end

  def handle_node(e)
    case e.name
    when 'anchor'  then e_anchor(e)
    when 'app'     then e_app(e)
    when 'g'       then e_g(e)
    when 'graphic' then e_graphic(e)
    when 'item'    then e_item(e)
    when 'lb'      then e_lb(e)
    when 'lem'     then e_lem(e)
    when 'note'    then e_note(e)
    when 'p'       then e_p(e)
    when 'rdg'     then e_rdg(e)
    when 'table'   then e_table(e)
    when 'tt'      then e_tt(e)
    else traverse(e)
    end
  end
  
  def handle_vol(folder)
    print "\rcheck vol: #{File.basename(folder)}  "
    Dir.entries(folder).sort.each do |f|
      next if f.start_with? '.'
      path = File.join(folder, f)
      handle_file(path)
    end
  end
  
  def read_notes(doc)
    @notes = Set.new
    doc.xpath('//note').each do |e|
      if e.key?('n')
        @notes << e['n']
      end
    end
  end

  def traverse(e)
    e.children.each { |c| 
      if c.text?
        chk_text(c)
      elsif e.element?
        handle_node(c)
      end
    }
  end
end
