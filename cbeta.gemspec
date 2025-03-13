Gem::Specification.new do |s|
  s.name        = 'cbeta'
  s.version     = '3.5.3'
  s.license     = 'MIT'
  s.date        = '2025-03-13'
  s.summary     = "CBETA Tools"
  s.description = "Ruby gem for use Chinese Buddhist Text resources made by CBETA (http://www.cbeta.org)."
  s.authors     = ["Ray Chou"]
  s.email       = 'zhoubx@gmail.com'
  s.files       = ['lib/cbeta.rb'] + Dir['lib/cbeta/*'] + Dir['lib/data/*']
  s.homepage    = 'https://github.com/RayCHOU/ruby-cbeta'
  s.required_ruby_version = '>= 3.0.0'
  s.add_runtime_dependency 'unihan2', '~> 1.1', '>= 1.1.0'
  s.add_runtime_dependency 'nokogiri', '~> 1.18', '>= 1.18.3'
  s.add_runtime_dependency 'csv', '~> 3.3', '>= 3.3.2'
end
