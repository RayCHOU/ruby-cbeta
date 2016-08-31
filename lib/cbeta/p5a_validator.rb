require 'nokogiri'

# 檢查 xml 是否符合 CBETA xml-p5a 編輯體例
# @example
#   require 'cbeta'
#   
#   RNG = '/Users/ray/Documents/Projects/cbeta/schema/cbeta-p5a.rng'
#   XML = '/Users/ray/Dropbox/DILA-CBETA/目次跨卷/xml/完成'
#   
#   v = CBETA::P5aValidator.new(RNG)
#   s = v.check(XML)
#   
#   if s.empty?
#     puts "檢查成功，未發現錯誤。"
#   else
#     File.write('check.log', s)
#     puts "發現錯誤，請查看 check.log。"
#   end
class CBETA::P5aValidator
  
  SEP = '-' * 20 # 每筆錯誤訊息之間的分隔
  
  private_constant :SEP
  
  # @param schema [String] RelaxNG schema file path
  def initialize(schema)
    @schema = schema
  end
  
  # @param xml_root [String] 來源 CBETA XML P5a 路徑
  # @return [String] 沒有錯誤的話，傳回空字串，否則傳回錯誤訊息。
  def check(xml_path)
    r = ''
    if Dir.exist? xml_path
      r = check_folder xml_path
    else
      r = check_file xml_path
    end
    r
  end
    
  private
    def check_folder(folder)
      r = ''
      Dir.entries(folder).each do |f|
        next if f.start_with? '.'
        path = File.join(folder, f)
        s = check_file path
        unless s.empty?
          r += path + "\n" + s + "\n" + SEP + "\n"
        end
      end
      r
    end
  
    def check_file(fn)
      puts "check #{fn}"
      @xml_fn = fn
      fi = File.open(fn)
      xml = fi.read
      fi.close
      
      r = check_well_form(xml)
      unless r.empty?
        return "not well-form\n#{r}"
      end
      
      r = validate(xml)
      unless r.empty?
        return "not valid\n#{r}"
      end
      
      check_text(xml)
    end
    
    def check_text(text)
      text.gsub!(/<!--.*-->/m, '')
      r = ''
      if text.include? ' <lb'
        r = 'lb 前不應有空格'
      end
      r
    end
    
    def check_well_form(xml)
      r = ''
      begin
        Nokogiri::XML(xml) { |config| config.strict }
      rescue Nokogiri::XML::SyntaxError => e
        r = "caught exception: #{e}"
      end
      r
    end
    
    def validate(xml)
      schema = Nokogiri::XML::RelaxNG(File.open(@schema))
      doc = Nokogiri::XML(xml)
      
      errors = schema.validate(doc)
      return '' if errors.empty?
      
      r = ''
      errors.each do |error|
        r += error.message + "\n"
      end
      r
    end
end