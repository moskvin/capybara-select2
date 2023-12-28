# frozen_string_literal: true

require 'capybara-select2/version'
require 'capybara/selectors/tag_selector'
require 'rspec/core'

module Capybara
  module Select2
    # Fill in a select2 filter and return the options.
    # @return [Array] the filtered options
    def select2_filter(value, **args)
      locator = find_select2_locator(value, **args)
      sleep(args[:sleep]) unless args[:sleep].nil?
      find(:xpath, '//body').find_all(locator.join(' '))
    end

    # Fill in a select2 field and select the value.
    # @param value [String]
    # @param insensitive [Boolean]
    # @param wait [Float]
    # @raise [Capybara::ElementNotFound]
    # @raise [Capybara::Ambiguous]
    def select2(value, insensitive: false, wait: nil, **args)
      text = insensitive ? /#{Regexp.escape(value)}/ : value
      locator = find_select2_locator(value, **args)
      sleep(wait) unless wait.nil?
      body = find(:xpath, '//body')
      if args[:exact_text]
        expect(body).to have_css(locator.last,
                                 exact_text: text,
                                 count: args[:expect_elements])
      else
        expect(body).to have_css(locator.last,
                                 text:,
                                 count: 1)
      end
      results = body.find_all(locator.join(' '))
      matches = results.select { |r| insensitive ? r.text.match?(text) : r.text == text }

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
    def find_select2_locator(value, **args)
      select2_container = find_select2_container(**args)
      open_select2(select2_container)

      # # Enter into the search box.
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
      find(:xpath, '//body').has_selector?('.loading_results')
    end
  end
end

RSpec.configure do |config|
  config.include Capybara::Select2
  config.include Capybara::Selectors::TagSelector
end
