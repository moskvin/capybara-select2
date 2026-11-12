# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Capybara::Select2 do
  [4, 3].each do |version|
    context "with select2 #{version}" do
      it 'selects the option with the exact text' do
        visit_fixture(version)

        select2('Apple', from: 'Fruit')

        expect(page).to have_css('#selected', exact_text: 'Apple')
      end

      it 'finds the field by xpath, css or label' do
        visit_fixture(version)

        select2('Banana', css: '.field .select2-container')
        expect(page).to have_css('#selected', exact_text: 'Banana')

        select2('Apple pie', css: '.field')
        expect(page).to have_css('#selected', exact_text: 'Apple pie')

        select2('Cherry', field: 'fruit')
        expect(page).to have_css('#selected', exact_text: 'Cherry')

        select2('Apple', xpath: find('.field .select2-container').path)
        expect(page).to have_css('#selected', exact_text: 'Apple')
      end

      it 'matches part of the text with mode: :insensitive and ignores case with :case_insensitive' do
        visit_fixture(version)

        select2('pie', from: 'Fruit', mode: :insensitive)
        expect(page).to have_css('#selected', exact_text: 'Apple pie')

        select2('BANANA', from: 'Fruit', mode: :case_insensitive)
        expect(page).to have_css('#selected', exact_text: 'Banana')
      end

      it 'fails when a partial match finds several options' do
        visit_fixture(version)

        expect { select2('Apple', from: 'Fruit', mode: :insensitive) }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'opens the dropdown again when it closes straight after opening' do
        visit_fixture(version, :close)

        select2('Banana', from: 'Fruit')

        expect(page).to have_css('#selected', exact_text: 'Banana')
      end

      it 'finds the field again when it is re-rendered under the click' do
        visit_fixture(version, :rerender)

        select2('Cherry', css: '.field .select2-container')

        expect(page).to have_css('#selected', exact_text: 'Cherry')
      end

      it 'fails fast, saying the dropdown did not open, when the field cannot open' do
        visit_fixture(version, :disabled)
        started = monotonic_now

        expect { select2('Apple', from: 'Fruit') }
          .to raise_error(Capybara::ExpectationNotMet, /select2 dropdown did not open after 3 clicks/)
        expect(monotonic_now - started).to be < Capybara.default_max_wait_time * 2
      end
    end
  end

  context 'with select2 4 results loaded from a slow source' do
    it 'waits for the search to finish' do
      visit_fixture(4, :slow)

      select2('Cherry', from: 'Fruit', search: true)

      expect(page).to have_css('#selected', exact_text: 'Cherry')
    end

    it 'polls for the option with await_option' do
      visit_fixture(4, :slow)

      select2('Banana', from: 'Fruit', await_option: true, max_retries: 10)

      expect(page).to have_css('#selected', exact_text: 'Banana')
    end

    it 'returns the filtered options with select2_filter' do
      visit_fixture(4, :slow)

      expect(select2_filter('an', from: 'Fruit', search: true).map(&:text)).to eq(['Banana'])
    end
  end

  # Applications copied 1.0.4's private helpers into their own spec support; mixed in after the gem, they used to
  # replace its internals.
  context 'when the spec defines helpers with the names 1.0.4 used' do
    %i[find_select2_container open_select2 find_select2_and_open fetch_options await_select2_option].each do |name|
      define_method(name) { |*, **| raise "#{name} from the application was called" }
    end

    it 'keeps using its own' do
      visit_fixture(4)

      select2('Banana', from: 'Fruit')

      expect(page).to have_css('#selected', exact_text: 'Banana')
    end
  end
end
