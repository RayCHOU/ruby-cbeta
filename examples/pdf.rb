require 'cbeta'

xml_root = '/Users/ray/git-repos/cbeta-xml-p5a'
html_root = '/temp/cbeta-html-for-pdf'
pdf_root = '/temp/cbeta-pdf'

# command to convert html to pdf
# you have to install prince first: http://www.princexml.com/
converter = 'prince %{in} -o %{out}'

options = {
  # graphic_base structure:
  #   figures/
  #   sd-gif/
  #   rj-gif/
  graphic_base: '/Users/ray/Documents/Projects/cbeta/images'  
}

# convert one volumn

c = CBETA::P5aToHTMLForPDF.new(xml_root, html_root, options)
c.convert('T10')

c = CBETA::HTMLToPDF.new(html_root, pdf_root, converter)
c.convert('T10')