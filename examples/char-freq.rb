require 'json'
require 'cbeta'

xml_root = '/Users/ray/git-repos/cbeta-xml-p5a'

# get Top 20 char frequency of Taisho Tripitake (大正藏)

c = CBETA::CharFrequency.new(xml_root, top: 20)
result = c.char_freq('T')

s = JSON.pretty_generate(result)
File.write('char-freq-taisho.json', s)

