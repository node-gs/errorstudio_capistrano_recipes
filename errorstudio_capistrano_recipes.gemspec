# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'version'

Gem::Specification.new do |spec|
  spec.name          = "errorstudio_capistrano_recipes"
  spec.version       = ErrorstudioCapistranoRecipes::VERSION
  spec.authors       = ["Ed Jones", "Paul Hendrick"]
  spec.email         = ["ed@error.agency", "paul@error.agency"]

  spec.summary       = %q{Error's cap recipes}
  spec.description   = %q{Cap recipes we use to deploy our websites.}
  spec.homepage      = "https://github.com/errorstudio/errorstudio_capistrano_recipes"
  spec.license       = "MIT"


  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"

  #production deps
  spec.add_dependency 'capistrano', '~>3.11.0'
  spec.add_dependency 'capistrano-composer', '>=0.0.6'
  spec.add_dependency 'capistrano-bundler'
  spec.add_dependency 'capistrano-rails'
  # spec.add_dependency 'capistrano-rvm'
  spec.add_dependency 'rvm1-capistrano3'
  spec.add_dependency 'capistrano-passenger'
end
