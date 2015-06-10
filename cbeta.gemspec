Gem::Specification.new do |s|
  s.name        = 'cbeta'
  s.version     = '0.0.6'
  s.date        = '2015-06-10'
  s.summary     = "CBETA Tools"
  s.description = "Ruby gem for use Chinese Buddhist Text resources made by CBETA (http://www.cbeta.org)."
  s.authors     = ["Ray Chou"]
  s.email       = 'zhoubx@gmail.com'
  s.files       = [
                    "lib/cbeta.rb", 
                    "lib/canons.csv",
                    "lib/cbeta/bm_to_text.rb",
                    "lib/cbeta/gaiji.rb",
                    "lib/cbeta/gaiji.json",
                    "lib/cbeta/html_to_text.rb",
                    "lib/cbeta/p5a_to_html.rb",
                    "lib/cbeta/unicode-1.1.json"
                  ]
  s.homepage    = 'https://github.com/RayCHOU/ruby-cbeta'
  s.license       = 'MIT'
end