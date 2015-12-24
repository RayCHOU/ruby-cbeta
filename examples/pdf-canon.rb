=begin
Requirements:
  Convert HTML documents to PDF
    需先安裝 prince: http://www.princexml.com/
=end

require 'cbeta'

xml_root = '/Users/ray/git-repos/cbeta-xml-p5a'
html_root = '/temp/cbeta-html-for-pdf'
pdf_root = '/temp/cbeta-pdf'

options = {
  # graphic_base structure:
  #   figures/
  #   sd-gif/
  #   rj-gif/
  graphic_base: '/Users/ray/Documents/Projects/cbeta/images',
}

# convert whole Taisho canon

c = CBETA::P5aToHTMLForPDF.new(xml_root, html_root, options)
c.convert('T')

c = CBETA::HTMLToPDF.new(html_root, pdf_root, "prince %{in} -o %{out}")
c.convert('T')