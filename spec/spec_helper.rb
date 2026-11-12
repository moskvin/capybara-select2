# frozen_string_literal: true

require 'capybara/dsl'
require 'capybara/rspec'
require 'capybara-select2'

# The fixtures are static pages with select2 and jQuery vendored next to them, opened as file:// URLs.
FIXTURES = File.expand_path('fixtures', __dir__)

Capybara.default_driver = :selenium_chrome_headless
Capybara.run_server = false
Capybara.default_max_wait_time = 2

RSpec.configure do |config|
  config.include Capybara::DSL
  config.disable_monkey_patching!
  config.order = :random
  config.after { Capybara.reset_sessions! }
end

def visit_fixture(version, scenario = nil)
  visit("file://#{FIXTURES}/select2-#{version}.html#{"?scenario=#{scenario}" if scenario}")
  expect(page).to have_css('.select2-container')
end

def monotonic_now
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
