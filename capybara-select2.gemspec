# frozen_string_literal: true

require 'English'

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'capybara-select2/version'

Gem::Specification.new do |gem|
  gem.name          = 'capybara-select2'
  gem.version       = Capybara::Select2::VERSION
  gem.authors       = ['William Yeung']
  gem.email         = ['william@tofugear.com']
  gem.description   = 'Helper for triggering select for select2 javascript library'
  gem.summary       = ''
  gem.homepage      = ''

  gem.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_dependency 'capybara'
  gem.add_dependency 'selenium-webdriver'

  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rubocop'
end
