# Ruby bools for access resources produced by CBETA 
# (Chinese Buddhist Electronic Text Association, http://www.cbeta.org)
#
# 存取 CBETA 資源的 Ruby 工具

require 'csv'

class CBETA
  DATA = File.join(File.dirname(__FILE__), 'data')
  PUNCS = '.[]。，、？「」『』《》＜＞〈〉〔〕［］【】〖〗'
  
  # 將行首資訊轉為引用格式
  #
  # @param linehead [String] 行首資訊, 例如：T85n2838_p1291a03
  # @return [String] 引用格式的出處資訊，例如：T85, no. 2838, p. 1291, a03
  # 
  # @example
  #   CBETA.linehead_to_s('T85n2838_p1291a03')
  #   # return "T85, no. 2838, p. 1291, a03"
  def self.linehead_to_s(linehead)
    linehead.match(/^([A-Z]\d+)n(.*)_p(\d+)([a-z]\d+)$/) {
      return "#{$1}, no. #{$2}, p. #{$3}, #{$4}"
    }
    nil
  end
  
  def self.open_xml(fn)
    s = File.read(fn)
    doc = Nokogiri::XML(s)
    doc.remove_namespaces!()
    doc
  end
  
  # 傳入 蘭札體 缺字碼，傳回 Unicode PUA 字元
  def self.ranjana_pua(gid)
    i = 0x10000 + gid[-4..-1].hex
    [i].pack("U")
  end
  
  # 傳入 悉曇字 缺字碼，傳回 Unicode PUA 字元
  def self.siddham_pua(gid)
    i = 0xFA000 + gid[-4..-1].hex
    [i].pack("U")
  end

	# 載入藏經資料
  def initialize()
    fn = File.join(File.dirname(__FILE__), 'data/canons.csv')
    text = File.read(fn)
    @canon_abbr = {}
    @canon_nickname = {}
    CSV.parse(text, :headers => true) do |row|
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
require 'cbeta/char_count'
require 'cbeta/char_freq'
require 'cbeta/html_to_pdf'
require 'cbeta/p5a_to_epub'
require 'cbeta/p5a_to_html'
require 'cbeta/p5a_to_html_for_every_edition'
require 'cbeta/p5a_to_html_for_pdf'
require 'cbeta/p5a_to_simple_html'
require 'cbeta/p5a_to_text'
require 'cbeta/p5a_validator'
require 'cbeta/html_to_text'