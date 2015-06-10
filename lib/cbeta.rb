# Ruby bools for access resources produced by CBETA 
# (Chinese Buddhist Electronic Text Association, http://www.cbeta.org)
#
# 存取 CBETA 資源的 Ruby 工具

require 'csv'

class CBETA
	# 載入藏經資料
  def initialize()
    fn = File.join(File.dirname(__FILE__), 'canons.csv')
    text = File.read(fn)
    @canon_abbr = {}
    CSV.parse(text, :headers => true) do |row|
      next if row['abbreviation'].nil?
    	next if row['abbreviation'].empty?
      @canon_abbr[row['id']] = row['abbreviation']
    end
  end

  # 取得藏經略符
  #
  # @param id [String] 藏經 ID, 例如大正藏的 ID 是 "T"
  # @return [String] 藏經略符，例如 "【大】"
  #
  # @example
  #   cbeta = CBETA.new
  #   cbeta.get_canon_abbr('T') # return "【大】"
	def get_canon_abbr(id)
		return nil unless @canon_abbr.key? id
		@canon_abbr[id]
	end
end
require 'cbeta/gaiji'
require 'cbeta/bm_to_text'
require 'cbeta/p5a_to_html'
require 'cbeta/html_to_text'