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
    if arg.size == 1
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
    @series = c
    puts 'convert_collection ' + c
    folder = File.join(@input, @series)
    Dir.foreach(folder) { |vol|
      next if ['.', '..', '.DS_Store'].include? vol
      convert_vol(vol)
    }
  end
  
  def convert_file(html_fn, pdf_fn)
    puts "convert file: #{html_fn} to #{pdf_fn}"
    cmd = @converter % { in: html_fn, out: pdf_fn}
    `#{cmd}`
  end
  
  def convert_vol(arg)
    vol = arg.upcase
    canon = vol[0]
    vol_folder = File.join(@input, canon, vol)
    
    output_folder = File.join(@output, canon, vol)
    FileUtils.mkdir_p(output_folder) unless Dir.exist? output_folder
    
    Dir.entries(vol_folder).sort.each do |f|
      next if f.start_with? '.'
      src = File.join(vol_folder, f, 'main.htm')  
      dest = File.join(output_folder, "#{f}.pdf")
      convert_file(src, dest)
    end
  end
  
  def convert_vols(v1, v2)
    puts "convert volumns: #{v1}..#{v2}"
    @series = v1[0]
    folder = File.join(@input, @series)
    Dir.foreach(folder) { |vol|
      next if vol < v1
      next if vol > v2
      convert_vol(vol)
    }
  end
  
end