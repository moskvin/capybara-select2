# frozen_string_literal: true

require 'capybara-select2/version'
require 'capybara/selectors/tag_selector'
require 'rspec/core'
require 'selenium/webdriver'

module Capybara
  module Select2
    # Fill in a select2 filter and return the options.
    # @return [Array] the filtered options
    def select2_filter(value, **args)
      locator = find_select2_and_open(value, **args)
      fetch_options(value, locator:, **args).find_all(locator.join(' '))
    end

    # Fill in a select2 field and select the value.
    # @param value [String]
    # @param args
    #   - mode [Symbol] - insensitive, case_insensitive or exact_text
    #   - wait [Float]
    # @raise [Capybara::ElementNotFound]
    # @raise [Capybara::Ambiguous]
    def select2(value, **args)
      text = case args[:mode]
             when :insensitive
               value.is_a?(Regexp) ? value : /#{Regexp.escape(value)}/
             when :case_insensitive
               /#{Regexp.escape(value)}/i
             else
               value
             end
      locator = find_select2_and_open(value, **args)
      body = fetch_options(text, locator:, **args)
      exact_text = args[:mode].nil? || args[:mode] == :exact_text
      if exact_text
        expect(body).to have_css(locator.last, exact_text: text)
      else
        expect(body).to have_css(locator.last, text:, count: 1)
      end

      results = body.find_all(locator.join(' '))
      matches = results.select { |r| exact_text ? r.text == text : r.text.match?(text) }

      case matches.size
      when 0
        raise Capybara::ElementNotFound, "Unable to find a matching option for #{value}"
      when 1
        matches.first.click
      else
        raise Capybara::Ambiguous, "Ambiguous match, found #{results.size} options for #{value}"
      end
    end

    private

    def fetch_options(text, locator:, **args)
      max_retries = args[:max_retries] || 5
      sleep(args[:wait]) unless args[:wait].nil?
      await_select2_option(text, locator:, max_retries:, mode: args[:mode]) if args[:await_option]
      body = find(:xpath, '//body')
      retries = 0

      begin
        if body.has_selector?('.loading_results',
                              wait: 0) && body.has_css?(locator.last, exact_text: 'Searching…', count: 1, wait: 0)
          sleep(args[:wait].nil? ? 0.1 : args[:wait])
          retries += 1
          if retries <= max_retries
            raise Capybara::ElementNotFound,
                  "Retry to find a matching option for #{text} attempt: #{retries} (Searching...)"
          end
        end
      rescue StandardError => e
        logger.warn(e.message)
        retry
      end
      body
    end

    def await_select2_option(text, locator:, mode:, max_retries:)
      body = find(:xpath, '//body')
      retries = 0
      begin
        options = if mode == :exact_text
                    { exact_text: text }
                  else
                    { text:, count: 1 }
                  end
        unless body.has_css?(locator.last, wait: (retries / 10.0), **options)
          sleep(0.3)
          retries += 1
          if retries <= max_retries
            raise Capybara::ElementNotFound,
                  "Retry to find a matching option for #{text}, mode: #{mode}, attempt: #{retries}/#{max_retries}"
          end
        end
      rescue StandardError => e
        logger.warn(e.message)
        retry
      end
    end

    def find_select2_container(**args)
      if args[:xpath]
        find(:xpath, args[:xpath])
      elsif args[:css]
        find(:css, args[:css])
      elsif args[:field]
        find(%(label[for="#{args[:field]}"])).find(:xpath, '..').find('.select2-container')
      elsif args[:from]
        find('label', text: args[:from]).find(:xpath, '..').find('.select2-container')
      else
        raise ArgumentError, 'None of xpath, css, field, nor from given'
      end
    end

    def open_select2(select2_container)
      if select2_container.has_selector?('.select2-selection') # select2 version 4.0
        select2_container.find('.select2-selection').click
      elsif select2_container.has_selector?('.select2-choice')
        select2_container.find('.select2-choice').click
      else
        select2_container.find('.select2-choices').click
      end
    end

    # Finds an opened select2 field
    # @param args:
    #   xpath [String]
    #   css [String]
    #   from [String]
    #   field [String]
    #   search [Boolean]
    #   sleep [Float]
    #   expect_elements [Integer]
    def find_select2_and_open(value, **args)
      select2_container = find_select2_container(**args)
      open_select2(select2_container)

      # Enter into the search box.
      drop_container = if args[:search]
                         find(:xpath, '//body')
                           .find('.select2-container--open input.select2-search__field')
                           .send_keys(value)
                         loop while loading_results?
                         '.select2-results'
                       elsif find(:xpath, '//body').has_selector?('.select2-dropdown') # select2 version 4.0
                         '.select2-dropdown'
                       else
                         '.select2-drop'
                       end

      results_selector = if find(:xpath, '//body').has_selector?("#{drop_container} li.select2-results__option") # select2 version 4.0
                           'li.select2-results__option'
                         else
                           'li.select2-result-selectable'
                         end
      [drop_container, results_selector]
    end

    def loading_results?
      find(:xpath, '//body').has_selector?('.loading-results')
    end

    def logger
      ::Selenium::WebDriver.logger
    end
  end
end

RSpec.configure do |config|
  config.include Capybara::Select2
  config.include Capybara::Selectors::TagSelector
end
