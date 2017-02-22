require File.expand_path('../lib/jobster/version', __FILE__)

Gem::Specification.new do |s|
  s.name          = "jobster"
  s.description   = %q{A RabbitMQ-based job queueing system}
  s.summary       = s.description
  s.homepage      = "https://github.com/adamcooke/jobster"
  s.licenses      = ['MIT']
  s.version       = Jobster::VERSION
  s.files         = Dir.glob("{bin,lib,vendor}/**/*")
  s.require_paths = ["lib"]
  s.authors       = ["Adam Cooke"]
  s.email         = ["me@adamcooke.io"]
  s.add_runtime_dependency 'bunny', '>= 2.2.0', '< 3'
end
