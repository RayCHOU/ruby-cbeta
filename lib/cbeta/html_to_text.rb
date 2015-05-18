require 'fileutils'
require 'nokogiri'

# 將 CBETA HTML 轉為 純文字(含行首資訊)
#
# Example:
#
#   h2t = CBETA::HTMLToText.new('/temp/cbeta-html', '/temp/cbeta-text')
#   h2t.convert("T01")  # 轉換大正藏第一冊
class CBETA::HTMLToText
  # html_root:: 來源 HTML 路徑
  # out_root:: 輸出路徑
  def initialize(html_root, out_root)
    @html_root = html_root
    @out_root = out_root
  end

  # Example:
  #
  # convert("T01")
  def convert(arg)
    @dirty = false
    @vol = arg.upcase
    @corpus = @vol[0]
    handle_vol
  end

  private

  def traverse(e)
    r = ''
    e.children.each { |c|
      r += handle_node(c)
    }
    r.gsub('　', '')
  end

  def handle_text(e)
    s = e.content().chomp
    return '' if s.empty?
    s.gsub(/[\n，、—！。：「]/, '')
  end

  def handle_span(e)
    r = ''
    case e['class']
    when 'doube-line-note'
      r = traverse(e)
      unless r.start_with? '（'
        r = "(#{r})"
      end
    when 'lb'
      if @dirty
        r += "\n"
      else
        @dirty = true
      end
      # 行首資訊 T05n0220a 改為 T05n0220
      lb = e['id'].sub(/^(T0\dn0220)[a-z](.*)$/, '\1\2')
      r += lb + '║'
    when 'lineInfo'
    when 'ranja'
      r = '【◇】'
    when 'siddam'
      r = '【◇】'
    when 'star'
    else
      r = traverse(e)
    end
    r
  end

  def handle_node(e)
    return '' if e.comment?
    return handle_text(e) if e.text?
    r = ''
    case e.name
    when 'a'
      if e['class'] == 'gaijiAnchor'
        id = e['href'][1..-1]
        r = @gaiji[id]
      else
        r = traverse(e)
      end
    when 'div'
      if e['id'] != 'back'
        r = traverse(e)
      end
    when 'head'
    when 'p'
      if e['class'] == 'figure'
        r = '【圖】'
      else
        r = traverse(e)
      end
    when 'span'
      r = handle_span(e)
    else
      r = traverse(e)
    end
    r
  end

  def prepare_folder()
    folder = File.join(@out_root, @corpus, @vol)
    FileUtils.remove_dir(folder, force=true)
    FileUtils.mkdir_p(folder)
    folder
  end

  def handle_file(path)
    sutra = File.basename(path, ".*")
    sutra.sub!(/^(.*)_.*$/, '\1')
    sutra.sub!(/(T\d\dn0220).*$/, '\1') # T0220 BM 沒有分 a, b, c...

    if sutra != @last_sutra
      txt_fn = sutra + '.txt'
      txt_path = File.join(@folder_out, txt_fn)
      puts "h2t #{txt_path}"
      @fo = File.open(txt_path, 'w')
      @last_sutra = sutra
      @dirty = false
    end

    f = File.open(path)
    doc = Nokogiri::HTML(f)
    f.close

    @gaiji = {}
    doc.css("span.gaijiInfo").each { |e|
      @gaiji[e['id']] = e['zzs']
    }

    text = traverse(doc.root)

    # 悉曇字
    text.gsub!(/(\((【◇】)+\)|（【◇】）|【◇】)+/, '【◇】')

    @fo.write(text)
  end

  def handle_vol()
    folder_in = File.join(@html_root, @corpus, @vol)
    @folder_out = prepare_folder
    @last_sutra = ''
    Dir["#{folder_in}/*"].each { |f|
      handle_file(f)
    }
  end

end