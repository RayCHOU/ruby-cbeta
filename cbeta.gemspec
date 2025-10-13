Gem::Specification.new do |s|
  s.name        = 'cbeta'
  s.version     = '3.7.0'
  s.license     = 'MIT'
  s.date        = '2025-10-13'
  s.summary     = "CBETA Tools"
  s.description = "Ruby gem for use Chinese Buddhist Text resources made by CBETA (http://www.cbeta.org)."
  s.authors     = ["Ray Chou"]
  s.email       = 'zhoubx@gmail.com'
  s.files       = ['lib/cbeta.rb'] + Dir['lib/cbeta/*'] + Dir['lib/data/*']
  s.homepage    = 'https://github.com/RayCHOU/ruby-cbeta'
  s.required_ruby_version = '>= 3.4.2'
  s.add_runtime_dependency 'unihan2', '~> 1.2', '>= 1.2.0'
  s.add_runtime_dependency 'nokogiri', '~> 1.18.9', '>= 1.18.9'
  s.add_runtime_dependency 'csv', '~> 3.3', '>= 3.3.2'
  s.cert_chain = ['certs/zhoubx.pem']
  s.signing_key = File.expand_path("~/.ssh/gem-private_key.pem") if $0 =~ /gem\z/
end
