require 'json'

# 存取 CBETA 缺字資料庫
class CBETA::Gaiji
	# 載入 CBETA 缺字資料庫
  def initialize()
    fn = File.join(File.dirname(__FILE__), '../data/gaiji.json')
    @gaijis = JSON.parse(File.read(fn))
  end

  # 取得缺字資訊
  #
  # @param cb [String] 缺字 CB 碼
  # @return [Hash{String => Strin, Array<String>}] 缺字資訊
  # @return [nil] 如果該 CB 碼在 CBETA 缺字庫中不存在
  #
  # @example
  #   g = Cbeta::Gaiji.new
  #   g["CB01002"]
  #
  # Return:
  #   {
  #     "zzs": "[得-彳]",
  #     "unicode": "3775",
  #     "unicode-char": "㝵",
  #     "zhuyin": [ "ㄉㄜˊ", "ㄞˋ" ]
  #   }
  def [](cb)
  	@gaijis[cb]
  end

  # 傳入缺字 CB 碼，傳回注音 array
  #
  # 資料來源：CBETA 於 2015.5.15 提供的 MS Access 缺字資料庫
  #
  # @param cb [String] 缺字 CB 碼
  # @return [Array<String>]
  #
  # @example
  #   g = Cbeta::Gaiji.new
  #   g.zhuyin("CB00023") # return [ "ㄍㄢˇ", "ㄍㄢ", "ㄧㄤˊ", "ㄇㄧˇ", "ㄇㄧㄝ", "ㄒㄧㄤˊ" ]
  def zhuyin(cb)
  	return nil unless @gaijis.key? cb
    @gaijis[cb]['zhuyin']
  end
end