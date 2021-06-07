# Ruby bools for access resources produced by CBETA 
# (Chinese Buddhist Electronic Text Association, http://www.cbeta.org)
#
# 存取 CBETA 資源的 Ruby 工具

require 'csv'

class CBETA
  CANON = 'DA|GA|GB|LC|ZS|ZW|[A-Z]'
  SORT_ORDER = %w(T X A K S F C D U P J L G M N ZS I ZW B GA GB Y LC)
  DATA = File.join(File.dirname(__FILE__), 'data')
  PUNCS = ',.()[] 。‧．，、；？！：︰／（）「」『』《》＜＞〈〉〔〕［］【】〖〗〃…—─　～│┬▆＊＋－＝'
  
  # 由 行首資訊 取得 藏經 ID
  # @param linehead[String] 行首資訊, 例如 "T01n0001_p0001a01" 或 "GA009n0008_p0003a01"
  # @return [String] 藏經 ID，例如 "T" 或 "GA"
  def self.get_canon_id_from_linehead(linehead)
    linehead.sub(/^(#{CANON}).*$/, '\1')
  end

  # 由 典籍編號 取得 藏經 ID
  # @param work[String] 典籍編號, 例如 "T0001" 或 "ZW0001"
  # @return [String] 藏經 ID，例如 "T" 或 "ZW"
  def self.get_canon_id_from_work_id(work)
    work.sub(/^(#{CANON}).*$/, '\1')
  end
  
  # 由 冊號 取得 藏經 ID
  # @param vol[String] 冊號, 例如 "T01" 或 "GA009"
  # @return [String] 藏經 ID，例如 "T" 或 "GA"
  def self.get_canon_from_vol(vol)
    vol.sub(/^(#{CANON}).*$/, '\1')
  end
  
  # @param file_basename[String] XML檔主檔名, 例如 "T01n0001" 或 "T25n1510a"
  # @param lb[String] 例如 "0001a01" 或 "0757b29"
  # @return [String] CBETA 行首資訊，例如 "T01n0001_p0001a01" 或 "T25n1510ap0757b29"
  def self.get_linehead(file_basename, lb)
    if file_basename.match(/^(T\d\dn0220)/)
      r = $1
    else
      r = file_basename
    end
    r += '_' if r.match(/\d$/)
    r += 'p' + lb
    r
  end
  
  # 由 冊號 及 典籍編號 取得 XML 主檔名
  # @param vol[String] 冊號, 例如 "T01" 或 "GA009"
  # @param work[String] 典籍編號, 例如 "T0001" 或 "GA0008"
  # @return [String] XML主檔名，例如 "T01n0001" 或 "GA009n0008"
  def self.get_xml_file_from_vol_and_work(vol, work)
    vol + 'n' + work.sub(/^(#{CANON})(.*)$/, '\2')
  end
  
  # 由 行首資訊 取得 XML檔相對路徑
  # @param linehead[String] 行首資訊, 例如 "GA009n0008_p0003a01"
  # @return [String] XML檔相對路徑，例如 "GA/GA009/GA009n0008.xml"
  def self.linehead_to_xml_file_path(linehead)
    if m = linehead.match(/^(?<work>(?<vol>(?<canon>#{CANON})\d+)n\d+[a-zA-Z]?).*$/)
      File.join(m[:canon], m[:vol], m[:work]+'.xml')
    else
      nil
    end
  end
  
  # 由 XML檔主檔名 取得 典籍編號
  # @param fn[String] 檔名, 例如 "T01n0001" 或 "GA009n0008"
  # @return [String] 典籍編號，例如 "T0001" 或 "GA0008"
  def self.get_work_id_from_file_basename(fn)
    r = fn.sub(/^(#{CANON})\d{2,3}n(.*)$/, '\1\2')
    r = 'T0220' if r.start_with? 'T0220'
    r
  end
  
  # 由「藏經 ID」取得「排序用編號」，例如：傳入 "T" 回傳 "A"；傳入 "X" 回傳 "B"
  # @param canon [String] 藏經 ID
  # @return [String] 排序用編號
  def self.get_sort_order_from_canon_id(canon)
    # CBETA 提供，惠敏法師最後決定的全文檢索順序表, 2016-06-03
    i = SORT_ORDER.index(canon)
    if i.nil?
      puts "unknown canon id: #{canon}" 
      return nil
    end
    
    (i + 'A'.ord).chr
  end
  
  # 將行首資訊轉為引用格式
  #
  # @param linehead [String] 行首資訊, 例如：T85n2838_p1291a03
  # @return [String] 引用格式的出處資訊，例如：T85, no. 2838, p. 1291, a03
  # 
  # @example
  #   CBETA.linehead_to_s('T85n2838_p1291a03')
  #   # return "T85, no. 2838, p. 1291, a03"
  def self.linehead_to_s(linehead)
    linehead.match(/^((?:#{CANON})\d+)n(.*)_p(\d+)([a-z]\d+)$/) {
      return "#{$1}, no. #{$2}, p. #{$3}, #{$4}"
    }
    nil
  end
  
  def self.normalize_vol(vol)
    if vol.match(/^(#{CANON})(.*)$/)
      canon = $1
      vol = $2
    
      if %w[A C G GA GB L M P U].include? canon
        # 這些藏經的冊號是三碼
        vol_len = 3
      else
        vol_len = 2      
      end
      canon + vol.rjust(vol_len, '0')
    else
      abort "unknown vol format: #{vol}"
    end
  end
  
  def self.open_xml(fn)
    s = File.read(fn)
    doc = Nokogiri::XML(s)
    doc.remove_namespaces!()
    doc
  end
  
  # 傳入 缺字碼，傳回 Unicode PUA 字元
  def self.pua(gid)
    if gid.start_with? 'SD'
      siddham_pua(gid)
    elsif gid.start_with? 'RJ'
      ranjana_pua(gid)
    else
      [0xf0000 + gid[2..-1].to_i].pack 'U'
    end
  end
  
  # 傳入 蘭札體 缺字碼，傳回 Unicode PUA 字元
  def self.ranjana_pua(gid)
    i = 0x100000 + gid[-4..-1].hex
    [i].pack("U")
  end
  
  # 傳入 悉曇字 缺字碼，傳回 Unicode PUA 字元
  def self.siddham_pua(gid)
    i = 0xFA000 + gid[-4..-1].hex
    [i].pack("U")
  end
  
  # 載入藏經資料
  def initialize()
    @canon_abbr = {}
    @canon_nickname = {}
    fn = File.join(File.dirname(__FILE__), 'data/canons.csv')
    CSV.foreach(fn, :headers => true, encoding: 'utf-8') do |row|
      id = row['id']
      unless row['nickname'].nil?
        @canon_nickname[id] = row['nickname']
      end
      next if row['abbreviation'].nil?
      next if row['abbreviation'].empty?
      @canon_abbr[id] = row['abbreviation']
    end
    
    fn = File.join(File.dirname(__FILE__), 'data/categories.json')
    s = File.read(fn)
    @categories = JSON.parse(s)
  end
  
  # @param id [String] 藏經 ID, 例如大正藏的 ID 是 "T"
  # @return [String] 藏經短名，例如 "大正藏"
  def get_canon_nickname(id)
    return nil unless @canon_nickname.key? id
    @canon_nickname[id]
  end
  
  # 取得藏經略符
  #
  # @param id [String] 藏經 ID, 例如大正藏的 ID 是 "T"
  # @return [String] 藏經略符，例如 "【大】"
  #
  # @example
  #   cbeta = CBETA.new
  #   cbeta.get_canon_symbol('T') # return "【大】"
  def get_canon_symbol(id)
    return nil unless @canon_abbr.key? id
    @canon_abbr[id]
  end
  
  # 取得藏經略名
  #
  # @param id [String] 藏經 ID, 例如大正藏的 ID 是 "T"
  # @return [String] 藏經短名，例如 "大"
  #
  # @example
  #   cbeta = CBETA.new
  #   cbeta.get_canon_abbr('T') # return "大"
	def get_canon_abbr(id)
    r = get_canon_symbol(id)
    return nil if r.nil?
    r.sub(/^【(.*?)】$/, '\1')
	end
  
  # 傳入經號，取得部類
  # @param book_id [String] Book ID (經號), ex. "T0220"
  # @return [String] 部類名稱，例如 "阿含部類"
  #
  # @example
  #   cbeta = CBETA.new
  #   cbeta.get_category('T0220') # return '般若部類'
  def get_category(book_id)
    @categories[book_id]
  end
    
end

require 'cbeta/gaiji'
require 'cbeta/bm_to_text'
require 'cbeta/canon'
require 'cbeta/char_count'
require 'cbeta/char_freq'
require 'cbeta/html_to_pdf'
require 'cbeta/p5a_to_html'
require 'cbeta/p5a_to_html_for_every_edition'
require 'cbeta/p5a_to_html_for_pdf'
require 'cbeta/p5a_to_simple_html'
require 'cbeta/p5a_to_text'
require 'cbeta/p5a_validator'
require 'cbeta/html_to_text'