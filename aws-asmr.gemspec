lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "aws/asmr/version"

Gem::Specification.new do |s|
  s.name         = "aws-asmr"
  s.version      = Aws::ASMR::VERSION
  s.summary      = "aws command line tool for ASMR. ASMR stands for AssumeRole, obviously!"
  s.description  = ""
  s.authors      = ["metheglin"]
  s.email        = "pigmybank@gmail.com"
  s.files        = Dir["{lib}/**/*.rb", "bin/*", "LICENSE", "*.md"]
  s.homepage     = "https://rubygems.org/gems/aws-asmr"
  s.executables  = %w(aws-asmr)
  s.require_path = 'lib'
  s.license      = "MIT"

  s.required_ruby_version = ">= 2.7"
  # s.add_dependency "rake", "~> 13.0"
  s.add_dependency "tty-prompt", '~> 0.0'
  s.add_dependency "aws-sdk-sts", '~> 1.0'
  s.add_dependency "aws-sdk-iam", '~> 1.0'
end