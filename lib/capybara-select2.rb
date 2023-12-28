# frozen_string_literal: true

require 'capybara-select2/version'
require 'capybara/selectors/tag_selector'
require 'rspec/core'

module Capybara
  module Select2
    # Fill in a select2 filter and return the options.
    # @return [Array] the filtered options
    def select2_filter(value, wait: nil, **args)
      locator = find_select2_and_open(value, **args)
      fetch_options(value, locator:, wait:, max_retries:).find_all(locator.join(' '))
    end

    # Fill in a select2 field and select the value.
    # @param value [String]
    # @param mode [Symbol] - insensitive, case_insensitive or exact_text
    # @param wait [Float]
    # @raise [Capybara::ElementNotFound]
    # @raise [Capybara::Ambiguous]
    def select2(value, mode: :exact_text, wait: nil, max_retries: 3, **args)
      text = case mode
             when :insensitive
               value.is_a?(Regexp) ? value : /#{Regexp.escape(value)}/
             when :case_insensitive
               /#{Regexp.escape(value)}/i
             else
               value
             end
      locator = find_select2_and_open(value, **args)
      body = fetch_options(value, locator:, wait:, max_retries:)
      if mode == :exact_text
        expect(body).to have_css(locator.last, exact_text: text)
      else
        expect(body).to have_css(locator.last, text:, count: 1)
      end
      warn 5
      results = body.find_all(locator.join(' '))
      matches = results.select { |r| mode == :exact_text ? r.text == text : r.text.match?(text) }

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

    def fetch_options(value, locator:, wait:, max_retries:)
      sleep(wait) unless wait.nil?
      body = find(:xpath, '//body')
      retries = 0

      begin
        if body.has_selector?('.loading_results',
                              wait: 0) && body.has_css?(locator.last, exact_text: 'Searching…', count: 1, wait: 0)
          sleep(wait.nil? ? 0.1 : wait)
          retries += 1
          if retries < max_retries
            raise Capybara::ElementNotFound,
                  "Retry to find a matching option for #{value} attempt: #{retries}"
          end
        end
      rescue StandardError => e
        warn e.message
        retry
      end
      find(:xpath, '//body')
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
  end
end

RSpec.configure do |config|
  config.include Capybara::Select2
  config.include Capybara::Selectors::TagSelector
end
