# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'heroku_vector/version'

Gem::Specification.new do |spec|
  spec.name          = "heroku-vector"
  spec.version       = HerokuVector::VERSION
  spec.authors       = ["Winfield Peterson"]
  spec.email         = ["winfield.peterson@gmail.com"]
  spec.summary       = %q{Sampling Auto-scaler for Heroku dynos}
  spec.description   = %q{Linearly scale Heroku dyno counts based on sampled metrics}
  spec.homepage      = "https://github.com/wpeterson/heroku-vector"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activeresource"
  spec.add_dependency "heroku-api"
  spec.add_dependency "newrelic_api"
  spec.add_dependency "redis"
  spec.add_dependency "redis-namespace"
  spec.add_dependency "sidekiq"
  spec.add_dependency "dotenv"
  spec.add_dependency "eventmachine"

  spec.add_development_dependency "minitest"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "vcr"
  spec.add_development_dependency "pry"
end
