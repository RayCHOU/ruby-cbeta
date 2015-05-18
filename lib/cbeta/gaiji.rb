require 'json'

# 存取 CBETA 缺字資料庫
class CBETA::Gaiji
	# 載入 CBETA 缺字資料庫
  def initialize()
    fn = File.join(File.dirname(__FILE__), 'gaiji.json')
    @gaijis = JSON.parse(File.read(fn))
  end

  # 傳入缺字 CB 碼，傳回 hash 缺字資訊
  #
  # 例如：
  #
  #   g = Cbeta::Gaiji.new
  #   g["CB01002"]
  #
  # 回傳：
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
  # 例如：
  #
  #   g = Cbeta::Gaiji.new
  #   g.zhuyin("CB00023") # return [ "ㄍㄢˇ", "ㄍㄢ", "ㄧㄤˊ", "ㄇㄧˇ", "ㄇㄧㄝ", "ㄒㄧㄤˊ" ]
  def zhuyin(cb)
  	return nil unless @gaijis.key? cb
    @gaijis[cb]['zhuyin']
  end
end