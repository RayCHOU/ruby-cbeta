require 'json'
require 'cbeta'

xml_root = '/Users/ray/git-repos/cbeta-xml-p5a'

c = CBETA::CharCount.new(xml_root)
result = c.char_count

s = JSON.pretty_generate(result)
File.write('char-count.json', s)

