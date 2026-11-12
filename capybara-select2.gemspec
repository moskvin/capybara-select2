# frozen_string_literal: true

require_relative 'lib/capybara-select2/version'

Gem::Specification.new do |spec|
  spec.name = 'capybara-select'
  spec.version = Capybara::Select2::VERSION
  spec.authors = ['William Yeung', 'Nikolay Moskvin']
  spec.email = ['william@tofugear.com']

  spec.summary = 'Capybara helpers to pick options in select2 (3.x and 4.x) fields'
  spec.description = 'select2 and select2_filter for Capybara/RSpec, with retries for dropdowns that close or ' \
                     're-render under the click and for results that load slowly. A fork of capybara-select2.'
  spec.homepage = 'https://github.com/moskvin/capybara-select2'
  spec.license = 'MIT'

  # Only files committed to git, so a local scratch file can never be published.
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, &:read).split("\x0").select do |f|
    f.start_with?('lib/') || %w[Changes.md LICENSE.txt README.md capybara-select2.gemspec].include?(f)
  end

  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata = {
    'homepage_uri' => 'https://github.com/moskvin/capybara-select2',
    'bug_tracker_uri' => 'https://github.com/moskvin/capybara-select2/issues',
    'changelog_uri' => 'https://github.com/moskvin/capybara-select2/blob/master/Changes.md',
    'source_code_uri' => 'https://github.com/moskvin/capybara-select2',
    'rubygems_mfa_required' => 'true'
  }

  spec.add_dependency 'capybara', '>= 3.0', '< 4'
  spec.add_dependency 'rspec-core', '>= 3.0', '< 4'
  spec.add_dependency 'rspec-expectations', '>= 3.0', '< 4'
  spec.add_dependency 'selenium-webdriver', '>= 4.0', '< 5'
end
