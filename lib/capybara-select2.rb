# frozen_string_literal: true

require 'capybara-select2/version'
require 'capybara/selectors/tag_selector'
require 'rspec/core'
require 'selenium/webdriver'

module Capybara
  module Select2
    # Clicks used to open a dropdown. A click can be lost when the field re-renders under it, or the dropdown can
    # close straight away; each attempt waits default_max_wait_time / OPEN_ATTEMPTS for it to open.
    OPEN_ATTEMPTS = 3

    # Markup per select2 major version. The version is read from the field itself, never from an open dropdown,
    # so a dropdown that failed to open is reported as such instead of as missing 3.x options.
    MARKUP = {
      4 => {
        trigger: '.select2-selection',
        open: '.select2-container--open',
        dropdown: '.select2-container--open .select2-dropdown',
        option: 'li.select2-results__option',
        search: '.select2-container--open input.select2-search__field',
        loading: '.loading-results'
      }.freeze,
      3 => {
        trigger: '.select2-choice, .select2-choices',
        open: '.select2-dropdown-open',
        dropdown: '.select2-drop-active',
        option: 'li.select2-result-selectable',
        search: '.select2-drop-active input.select2-input',
        loading: '.select2-searching'
      }.freeze
    }.freeze

    # Fill in a select2 filter and return the options.
    # @return [Array] the filtered options
    def select2_filter(value, **args)
      markup = select2_find_and_open(value, **args)
      select2_fetch_options(value, markup:, **args).find_all(select2_option_selector(markup))
    end

    # Fill in a select2 field and select the value.
    # @param value [String, Regexp]
    # @param args
    #   - xpath, css, from or field [String] - locates the select2 container
    #   - mode [Symbol] - :exact_text (default), :insensitive or :case_insensitive
    #   - search [Boolean] - type the value into the search box first
    #   - wait [Float] - sleep this long before reading the options
    #   - await_option [Boolean] - poll for the option before reading the options
    #   - max_retries [Integer] - polls for await_option (default 5)
    # @raise [Capybara::ElementNotFound]
    # @raise [Capybara::Ambiguous]
    # @raise [Capybara::ExpectationNotMet] when the dropdown does not open
    def select2(value, **args)
      text = select2_match_text(value, args[:mode])
      exact_text = select2_exact_text?(args[:mode])
      option = exact_text ? { exact_text: text } : { text:, count: 1 }
      markup = select2_open_with_option(value, text, option, **args)
      expect(select2_body).to have_css(select2_option_selector(markup), wait: 0, **option)

      select2_pick_option(value, text, exact_text, markup)
    end

    private

    # Private helpers are prefixed with select2_: they are mixed into every example, so a spec helper with the same
    # name would otherwise replace them.

    def select2_pick_option(value, text, exact_text, markup)
      matches = select2_body.find_all(select2_option_selector(markup)).select do |result|
        exact_text ? result.text == text : result.text.match?(text)
      end

      case matches.size
      when 0
        raise Capybara::ElementNotFound, "Unable to find a matching option for #{value}"
      when 1
        matches.first.click
      else
        raise Capybara::Ambiguous, "Ambiguous match, found #{matches.size} options for #{value}"
      end
    end

    def select2_monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def select2_match_text(value, mode)
      case mode
      when :insensitive
        value.is_a?(Regexp) ? value : /#{Regexp.escape(value)}/
      when :case_insensitive
        /#{Regexp.escape(value)}/i
      else
        value
      end
    end

    def select2_exact_text?(mode)
      mode.nil? || mode == :exact_text
    end

    # Opens the dropdown and waits for the option. A dropdown that closes before the option is listed (the field
    # re-rendered, as a lookup updating a form does) is opened again; one that stays open without it is left to
    # select2's expectation to report.
    def select2_open_with_option(value, text, option, **args)
      OPEN_ATTEMPTS.times do
        markup = select2_find_and_open(value, **args)
        select2_fetch_options(text, markup:, **args)
        return markup if select2_option_listed_or_open?(markup, option)
      end
      raise Capybara::ExpectationNotMet, "select2 dropdown closed before listing #{value} #{OPEN_ATTEMPTS} times"
    end

    # true once the option is listed, or when default_max_wait_time passes with the dropdown still open;
    # false as soon as the dropdown closes.
    def select2_option_listed_or_open?(markup, option)
      deadline = select2_monotonic_now + Capybara.default_max_wait_time
      body = select2_body
      loop do
        return true if body.has_css?(select2_option_selector(markup), wait: 0, **option)
        return false unless body.has_selector?(markup[:dropdown], wait: 0)
        return true if select2_monotonic_now >= deadline

        sleep(0.05)
      end
    end

    def select2_option_selector(markup)
      "#{markup[:dropdown]} #{markup[:option]}"
    end

    def select2_body
      find(:xpath, '//body')
    end

    def select2_fetch_options(text, markup:, **args)
      sleep(args[:wait]) unless args[:wait].nil?
      if args[:await_option]
        select2_await_option(text, markup:, max_retries: args[:max_retries] || 5, mode: args[:mode])
      end
      select2_await_loaded(markup)
      select2_body
    end

    # Polls with a growing wait until the option is listed; select2 then fails with Capybara's own message.
    def select2_await_option(text, markup:, mode:, max_retries:)
      options = select2_exact_text?(mode) ? { exact_text: text } : { text:, count: 1 }
      (max_retries + 1).times do |attempt|
        break if select2_body.has_css?(select2_option_selector(markup), wait: attempt / 10.0, **options)

        sleep(0.3)
        select2_logger.warn("Retry to find a matching option for #{text}, mode: #{mode}, " \
                            "attempt: #{attempt + 1}/#{max_retries}")
      end
    end

    # Waits, up to default_max_wait_time, while the dropdown shows "Searching…".
    def select2_await_loaded(markup)
      deadline = select2_monotonic_now + Capybara.default_max_wait_time
      loading = "#{markup[:dropdown]} #{markup[:loading]}"
      sleep(0.05) while select2_body.has_selector?(loading, wait: 0) && select2_monotonic_now < deadline
    end

    def select2_find_container(**args)
      if args[:xpath]
        select2_container_in(find(:xpath, args[:xpath]))
      elsif args[:css]
        select2_container_in(find(:css, args[:css]))
      else
        select2_container_next_to(select2_find_label(**args))
      end
    end

    def select2_find_label(**args)
      if args[:field]
        find(%(label[for="#{args[:field]}"]))
      elsif args[:from]
        # select2 3.x copies the label into its container as an off-screen label
        find('label:not(.select2-offscreen)', text: args[:from])
      else
        raise ArgumentError, 'None of xpath, css, field, nor from given'
      end
    end

    def select2_container_next_to(label)
      label.find(:xpath, '..').find('.select2-container')
    end

    # xpath: and css: may point at the select2 container or at an element wrapping it (such as a form field).
    def select2_container_in(element)
      return element if element.matches_css?('.select2-container', wait: 0)

      element.find('.select2-container', match: :first)
    end

    def select2_version(container)
      return 4 if container.has_selector?(MARKUP[4][:trigger], wait: 0)
      return 3 if container.has_selector?(MARKUP[3][:trigger], wait: 0)

      # Not rendered yet: wait once for either version.
      container.has_selector?("#{MARKUP[4][:trigger]}, #{MARKUP[3][:trigger]}")
      container.has_selector?(MARKUP[4][:trigger], wait: 0) ? 4 : 3
    end

    # Clicks the field until its dropdown opens. A field re-rendered under the click is found again.
    def select2_open(container, markup, **args)
      wait = Capybara.default_max_wait_time.to_f / OPEN_ATTEMPTS
      OPEN_ATTEMPTS.times do
        return if container.matches_css?(markup[:open], wait: 0)

        container.find(markup[:trigger], match: :first).click
        return if container.matches_css?(markup[:open], wait:)
      rescue Selenium::WebDriver::Error::StaleElementReferenceError
        container = select2_find_container(**args)
      end
      raise Capybara::ExpectationNotMet,
            "select2 dropdown did not open after #{OPEN_ATTEMPTS} clicks on #{markup[:trigger]}"
    end

    # Opens the field (typing the value into the search box with `search: true`) and returns its MARKUP.
    def select2_find_and_open(value, **args)
      container = select2_find_container(**args)
      markup = MARKUP.fetch(select2_version(container))
      select2_open(container, markup, **args)

      if args[:search]
        select2_body.find(markup[:search]).send_keys(value)
        select2_await_loaded(markup)
      end
      markup
    end

    def select2_logger
      ::Selenium::WebDriver.logger
    end
  end
end

RSpec.configure do |config|
  config.include Capybara::Select2
  config.include Capybara::Selectors::TagSelector
end
