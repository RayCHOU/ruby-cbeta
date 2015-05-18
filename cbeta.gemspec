Gem::Specification.new do |s|
  s.name        = 'cbeta'
  s.version     = '0.0.1'
  s.date        = '2015-05-18'
  s.summary     = "CBETA Tools"
  s.description = "Ruby gem for use CBETA resources"
  s.authors     = ["Ray Chou"]
  s.email       = 'zhoubx@gmail.com'
  s.files       = [
                    "lib/cbeta.rb", 
                    "lib/cbeta/bm_to_text.rb",
                    "lib/cbeta/gaiji.rb",
                    "lib/cbeta/gaiji.json",
                    "lib/cbeta/html_to_text.rb",
                    "lib/cbeta/p5a_to_html.rb",
                    "lib/cbeta/unicode-1.1.json"
                  ]
  s.homepage    = 'http://rubygems.org/gems/cbeta'
  s.license       = 'MIT'
end