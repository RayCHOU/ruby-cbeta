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
  graphic_base: '/Users/ray/Documents/Projects/cbeta/images',
  front_page: '/Users/ray/Dropbox/CBETA/pdf/readme.htm',
  front_page_title: '編輯說明',
  back_page: '/Users/ray/Dropbox/CBETA/pdf/donate.htm',
  back_page_title: '贊助資訊',  
}

# convert one volumn

c = CBETA::P5aToHTMLForPDF.new(xml_root, html_root, options)
c.convert('T01..T02')

c = CBETA::HTMLToPDF.new(html_root, pdf_root, converter)
c.convert('T01..T02')