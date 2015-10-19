Gem::Specification.new do |s|
  s.name        = 'cbeta'
  s.version     = '1.1.12'
  s.date        = '2015-10-19'
  s.summary     = "CBETA Tools"
  s.description = "Ruby gem for use Chinese Buddhist Text resources made by CBETA (http://www.cbeta.org)."
  s.authors     = ["Ray Chou"]
  s.email       = 'zhoubx@gmail.com'
  s.files       = [
                    "lib/cbeta.rb", 
                    "lib/cbeta/bm_to_text.rb",
                    "lib/cbeta/gaiji.rb",
                    "lib/cbeta/html_to_text.rb",
                    "lib/cbeta/p5a_to_epub.rb",
                    "lib/cbeta/p5a_to_html.rb",
                    "lib/cbeta/p5a_to_html_for_every_edition.rb",
                    "lib/cbeta/p5a_to_simple_html.rb",
                    "lib/cbeta/p5a_to_text.rb",
                    "lib/cbeta/p5a_validator.rb",
                    ] + Dir['lib/data/*']
  s.homepage    = 'https://github.com/RayCHOU/ruby-cbeta'
  s.license       = 'MIT'
end