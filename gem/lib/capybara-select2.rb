require 'capybara-select2/version'
require 'capybara/selectors/tag_selector'
require 'rspec/core'

module Capybara
  module Select2

    # Fill in a select2 filter and return the options.
    # @return [Array] the filtered options
    def select2_filter(value, **args)
      find_select2(value, **args)
    end
    
    # Fill in a select2 field and select the value.
    # @param value [String]
    # @param case_insensitive [Boolean]
    # @raise [Capybara::ElementNotFound]
    # @raise [Capybara::Ambiguous]
    def select2(value, case_insensitive: false, **args)
      results = find_select2(value, **args)
      
      text = case_insensitive ? /#{value}/i : value
      matches = results.select { |r| text === r.text }
      
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

    # Finds an opened select2 field
    # @param xpath [String]
    # @param css [String]
    # @param from [String]
    # @param field [String]
    # @param search [Boolean]
    # @param sleep [Float]
    def find_select2(value, xpath: nil, css: nil, from: nil, field: nil, search: nil, sleep: nil)
      select2_container = case
                          when xpath
                            find(:xpath, xpath)
                          when css
                            find(:css, css)
                          when field
                            find(%{label[for="#{field}"]}).find(:xpath, '..').find('.select2-container')
                          when from
                            find('label', text: from).find(:xpath, '..').find('.select2-container')
                          else
                            raise ArgumentError, 'None of xpath, css, field, nor from given'
                          end

      # Open select2 field
      if select2_container.has_selector?('.select2-selection') # select2 version 4.0
        select2_container.find('.select2-selection').click
      elsif select2_container.has_selector?('.select2-choice')
        select2_container.find('.select2-choice').click
      else
        select2_container.find('.select2-choices').click
      end

      # Enter into the search box.
      drop_container = case
                       when search
                         find(:xpath, '//body')
                           .find('.select2-container--open input.select2-search__field')
                           .send_keys(value)
                         loop while loading_results?
                         '.select2-results'
                       when find(:xpath, '//body').has_selector?('.select2-dropdown') # select2 version 4.0
                         '.select2-dropdown'
                       else
                         '.select2-drop'
                       end

      results_selector = if find(:xpath, "//body").has_selector?("#{drop_container} li.select2-results__option") # select2 version 4.0
                           'li.select2-results__option'
                         else
                           'li.select2-result-selectable'
                         end
      sleep(sleep) if sleep.present?
      find(:xpath, '//body').find_all("#{drop_container} #{results_selector}")
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
