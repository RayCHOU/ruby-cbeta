require 'json'

# 存取 CBETA 缺字資料庫
class CBETA::Gaiji
  # 載入 CBETA 缺字資料庫
  # gaiji_base clone from https://github.com/cbeta-org/cbeta_gaiji
  def initialize(gaiji_base)
    fn = File.join(gaiji_base, 'cbeta_gaiji.json')
    @gaijis = JSON.parse(File.read(fn))
    
    fn = File.join(gaiji_base, 'cbeta_sanskrit.json')
    h = JSON.parse(File.read(fn))
    @gaijis.merge!(h)
    
    @zzs = {}
    @uni2cb = {}
    @gaijis.each do |k,v|
      if v.key? 'composition'
        zzs = v['composition']
        @zzs[zzs] = k
      end
      
      if v.key? 'uni_char'
        c = v['uni_char']
        @uni2cb[c] = k
      end
    end
  end

  # 取得缺字資訊
  #
  # @param cb [String] 缺字 CB 碼
  # @return [Hash{String => Strin, Array<String>}] 缺字資訊
  # @return [nil] 如果該 CB 碼在 CBETA 缺字庫中不存在
  #
  # @example
  #   g = CBETA::Gaiji.new
  #   g["CB01002"]
  #
  # Return:
  #   {
  #     "composition": "[得-彳]",
  #     "unicode": "3775",
  #     "uni_char": "㝵",
  #     "zhuyin": [ "ㄉㄜˊ", "ㄞˋ" ]
  #   }
  def [](cb)
  	@gaijis[cb]
  end
  
  # 檢查某個缺字碼是否存在
  def key?(cb)
    @gaijis.key? cb
  end
  
  # 依優先序呈現缺字
  def to_s(gid, cb_priority=nil, skt_priority=nil)
    if cb_priority.nil?
      cb_priority = %w(uni_char norm_uni_char norm_big5_char composition)
    end
    
    if skt_priority.nil?
      skt_priority = %w(symbol romanized PUA)
    end
    
    g = @gaijis[gid]
    if gid.start_with? 'CB'
      cb_priority.each do |k|
        if k == 'PUA'
          return CBETA.pua(gid)
        elsif g.key? k
          return g[k] unless g[k].empty?
        end
      end
    else
      skt_priority.each do |k|
        if k == 'PUA'
          s = g['pua'].sub(/^U\+(.*)$/, '\1')
          i = s.to_i(16)
          return [i].pack("U")
        else
          if g.key? k
            return g[k] unless g[k].empty?
          end
        end
      end
    end
    nil
  end
  
  def unicode_to_cb(unicode_char)
    @uni2cb[unicode_char]
  end

  # 傳入缺字 CB 碼，傳回注音 array
  #
  # 資料來源：CBETA 於 2015.5.15 提供的 MS Access 缺字資料庫
  #
  # @param cb [String] 缺字 CB 碼
  # @return [Array<String>]
  #
  # @example
  #   g = CBETA::Gaiji.new
  #   g.zhuyin("CB00023") # return [ "ㄍㄢˇ", "ㄍㄢ", "ㄧㄤˊ", "ㄇㄧˇ", "ㄇㄧㄝ", "ㄒㄧㄤˊ" ]
  def zhuyin(cb)
  	return nil unless @gaijis.key? cb
    @gaijis[cb]['zhuyin']
  end
  
  # 傳入 組字式，取得 PUA
  def zzs2pua(zzs)
    return nil unless @zzs.key? zzs
    gid = @zzs[zzs]
    CBETA.pua(gid)
  end
  
end