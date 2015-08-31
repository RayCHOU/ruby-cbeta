require 'cbeta'

TEMP = '/temp/epub-work'
README = '/Users/ray/Dropbox/CBETA/epub/readme.xhtml'
DONATE = '/Users/ray/Dropbox/CBETA/epub/donate.xhtml'

# 設定這部經由哪些 XML 組成
xml_files = [
  '/Users/ray/git-repos/cbeta-xml-p5a/T/T05/T05n0220a.xml',
  '/Users/ray/git-repos/cbeta-xml-p5a/T/T06/T06n0220b.xml',
  '/Users/ray/git-repos/cbeta-xml-p5a/T/T07/T07n0220c.xml',
  '/Users/ray/git-repos/cbeta-xml-p5a/T/T07/T07n0220d.xml',
  '/Users/ray/git-repos/cbeta-xml-p5a/T/T07/T07n0220e.xml',
  '/Users/ray/git-repos/cbeta-xml-p5a/T/T07/T07n0220f.xml',
  '/Users/ray/git-repos/cbeta-xml-p5a/T/T07/T07n0220g.xml',
  '/Users/ray/git-repos/cbeta-xml-p5a/T/T07/T07n0220h.xml',
  '/Users/ray/git-repos/cbeta-xml-p5a/T/T07/T07n0220i.xml',
  '/Users/ray/git-repos/cbeta-xml-p5a/T/T07/T07n0220j.xml',
  '/Users/ray/git-repos/cbeta-xml-p5a/T/T07/T07n0220k.xml',
  '/Users/ray/git-repos/cbeta-xml-p5a/T/T07/T07n0220l.xml',
  '/Users/ray/git-repos/cbeta-xml-p5a/T/T07/T07n0220m.xml',
  '/Users/ray/git-repos/cbeta-xml-p5a/T/T07/T07n0220n.xml',
  '/Users/ray/git-repos/cbeta-xml-p5a/T/T07/T07n0220o.xml',
]

options = {
  epub_version: 3,
  front_page: README,
  front_page_title: '編輯說明',
  back_page: DONATE,
  back_page_title: '贊助資訊',
}

c = CBETA::P5aToEPUB.new(TEMP, options)
c.convert_sutra('T0220', '大般若經', xml_files, '/temp/cbeta-epub/T0220.epub')