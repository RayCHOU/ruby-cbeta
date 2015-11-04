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

c = CBETA::P5aToHTMLForPDF.new(xml_root, html_root, options)
c.convert('T54')

c = CBETA::HTMLToPDF.new(html_root, pdf_root)
c.convert('T54')