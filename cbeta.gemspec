Gem::Specification.new do |s|
  s.name        = 'cbeta'
  s.version     = '2.7.1'
  s.license     = 'MIT'
  s.date        = '2018-07-21'
  s.summary     = "CBETA Tools"
  s.description = "Ruby gem for use Chinese Buddhist Text resources made by CBETA (http://www.cbeta.org)."
  s.authors     = ["Ray Chou"]
  s.email       = 'zhoubx@gmail.com'
  s.files       = ['lib/cbeta.rb'] + Dir['lib/cbeta/*'] + Dir['lib/data/*']
  s.homepage    = 'https://github.com/RayCHOU/ruby-cbeta'
end