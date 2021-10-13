require 'fileutils'

class CBETA::HTMLToPDF
  # @param input [String] folder of source HTML, HTML can be produced by CBETA::P5aToHTMLForPDF.
  # @param output [String] output folder
  # @param converter [String] shell command to convert HTML to PDF
  #   * suggestion: http://www.princexml.com/
  #   * wkhtmltopdf has font problem to display unicode extb characters
  #
  # @example
  #   c = CBETA::HTMLToPDF.new('/temp/cbeta-html', '/temp/cbeta-pdf', "prince %{in} -o %{out}")
  def initialize(input, output, converter)
    @input = input
    @output = output
    @converter = converter
  end
  
  # Convert CBETA HTML to PDF
  #
  # @example for convert Taisho (大正藏) Volumn 1:
  #
  #   c = CBETA::HTMLToPDF.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
  #   c.convert('T01')
  #
  # @example for convert all in Taisho (大正藏):
  #
  #   c = CBETA::HTMLToPDF.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
  #   c.convert('T')
  #
  # @example for convert Taisho Vol. 5~7:
  #
  #   c = CBETA::P5aToHTMLForPDF.new('/PATH/TO/CBETA/XML/P5a', '/OUTPUT/FOLDER')
  #   c.convert('T05..T07')
  #
  # T 是大正藏的 ID, CBETA 的藏經 ID 系統請參考: http://www.cbeta.org/format/id.php
  def convert(target=nil)
    return convert_all if target.nil?

    arg = target.upcase
    if arg.size <= 2
      convert_collection(arg)
    else
      if arg.include? '..'
        arg.match(/^([^\.]+?)\.\.([^\.]+)$/) {
          convert_vols($1, $2)
        }
      else
        convert_vol(arg)
      end
    end
  end
  
  def convert_collection(c)
    @canon = c
    puts 'convert_collection ' + c
    
    output_folder = File.join(@output, @canon)
    FileUtils.mkdir_p(output_folder) unless Dir.exist? output_folder
    
    folder = File.join(@input, @canon)
    Dir.foreach(folder) { |f|
      next if f.start_with? '.'
      src = File.join(folder, f, 'main.htm')
      dest = File.join(output_folder, "#{f}.pdf")
      convert_file(src, dest)
    }
  end
  
  def convert_file(html_fn, pdf_fn)
    puts "convert file: #{html_fn} to #{pdf_fn}"
    cmd = @converter % { in: html_fn, out: pdf_fn}
    `#{cmd}`
  end
    
end