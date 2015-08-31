require 'cbeta'

TEMP = '/temp/epub-work'
IMG = '/Users/ray/Documents/Projects/D道安/figures-for-epub'
README = '/Users/ray/Dropbox/CBETA/epub/readme-道安專案.xhtml'
DONATE = '/Users/ray/Dropbox/CBETA/epub/donate-道安專案.xhtml'

options = {
  epub_version: 3,
  front_page: README,
  front_page_title: '編輯說明',
  back_page: DONATE,
  back_page_title: '贊助資訊',
  graphic_base: IMG, 
}
c = CBETA::P5aToEPUB.new(TEMP, options)
c.convert_folder('/Users/ray/Documents/Projects/D道安/xml-p5a/DA/DA01', '/temp/cbeta-epub/DA/DA01')