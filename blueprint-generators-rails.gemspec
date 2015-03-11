# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'blueprint/generators/rails/version'

Gem::Specification.new do |spec|
  spec.name          = "blueprint-generators-rails"
  spec.version       = Blueprint::Generators::Rails::VERSION
  spec.authors       = ["benjii"]
  spec.email         = ["ben.deany@gmail.com"]

  spec.summary       = %q{Blueprint PogoScript generators for diagrams.}
  spec.homepage      = "http://blooming-waters-9183.herokuapp.com"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rake", "~> 10.0"
end
