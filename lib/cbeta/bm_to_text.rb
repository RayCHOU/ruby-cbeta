require 'fileutils'

# 將 CBETA Basic Markup 格式檔 轉為 純文字(含行首資訊)
#
# CBETA Basic Markup 格式可由此取得: https://github.com/mahawu/BM_u8
#
# Example:
#
#   bm2t = CBETA::BMToText.new('/temp/cbeta-bm', '/temp/cbeta-text1')
#   bm2t.convert('T01')  # 執行大正藏第一冊
class CBETA::BMToText

  # @param bm_root [String] 來源 CBETA Basic Markup 檔案路徑
  # @param out_root [String] 輸出路徑
  def initialize(bm_root, out_root)
    @bm_root = bm_root
    @out_root = out_root
  end

  # vol:: 要執行的冊號，例如：T01
  def convert(vol)
    @corpus = vol[0]
    handle_vol(vol)
  end

  private

  def prepare_folder(vol)
    folder = File.join(@out_root, @corpus, vol)
    unless Dir.exist? folder
      FileUtils.mkdir_p(folder)
    end
    folder
  end

  def handle_vol(vol)
    path = File.join(@bm_root, @corpus, vol, 'new.txt')
    fo = nil
    last_sutra = ''
    dirty = false
    char = '(?:\[[^\]]+\]|[^\[\]])'
    File.open(path, 'r').each_line { |line|
      line.match(/^(\D+\d+n.{5})(.{8})...(.*)$/) {
        @sutra = $1.chomp('_')
        lb = $2
        text = $3
        line_head = "#{@sutra}_#{lb}"
        if last_sutra != @sutra
          folder = prepare_folder(vol)
          fn = "#{@sutra}.txt"
          path = File.join(folder, fn)
          puts "bm2t #{path}"
          fo = File.open(path, 'w')
          dirty = false
          last_sutra = @sutra
        end
        text.gsub!(/<[^>]+>/, '')
        text.gsub!(/\[\d+[A-Z]?\]/, '') # 去掉校勘註標, 例 [01], [02A]
        text.gsub!(/\[＊\]|Ａ|Ｂ|Ｄ|Ｉ|Ｍ|Ｐ|Ｑ|Ｒ|Ｓ|Ｔ|Ｗ|Ｚ|ｊ|ｓ|　/, '')

        text.sub!('[𪄱鴹>[𪄲鴹;商羊]]', '𪄲鴹') # T39n1799_p0939c06

        # 通用詞 [䠒跪;胡跪]
        text.gsub!(/\[([^; ]*);[^\] ]*\]/, '\1')

        # 修訂 [A>B]
        reg = Regexp.new("\\[#{char}*>(#{char}*)\\]")
        text.gsub!(reg, '\1')

        # 悉曇字
        text.gsub!(/(（【◇】）|\(【◇】\)|【◇】|（◇）|◇)+/, '【◇】')
        text.gsub!('(（？）)', '（？）')

        # 去掉不比對的標點
        text.gsub!(/(\[[^\[\]]+\]|[，、—！。：「])/) { |s|
          if s.size > 1
            s
          else
            ''
          end
        }

        if dirty
          fo.puts
        else
          dirty = true
        end
        fo.write("#{line_head}║#{text}")
      }
    }
    fo.close
  end

end