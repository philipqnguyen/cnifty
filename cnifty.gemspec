lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cnifty/version'

Gem::Specification.new do |s|
  s.name        = 'cnifty'
  s.version     = Cnifty::VERSION
  s.summary     = 'Cardano NFT creator and node interface for Ruby'
  s.description = 'This is an interface to Cardano Node, designed to make creating NFTs easier via Ruby easier.'
  s.license     = 'MIT'
  s.authors     = ['Philip Nguyen']
  s.email       = 'supertaru@gmail.com'
  s.files       = `git ls-files lib README.md CHANGELOG.md LICENSE.txt`.split("\n")
  s.homepage    = 'https://github.com/philipqnguyen/cnifty'
  s.license     = 'MIT'
  s.required_ruby_version = '>= 3.0.0'
end
