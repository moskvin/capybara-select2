# capybara-select

[![CI](https://github.com/moskvin/capybara-select2/actions/workflows/ci.yml/badge.svg)](https://github.com/moskvin/capybara-select2/actions/workflows/ci.yml)

Capybara helpers to pick an option in a [select2](https://select2.org) field (4.x and 3.x), for RSpec feature specs
run with Selenium.

A fork of [capybara-select2](https://github.com/goodwill/capybara-select2), released as `capybara-select` because the
original name is taken on rubygems.org. It keeps the original's `require` name and `Capybara::Select2` module, and
adds what flaky browser specs need:

- a click that does not open the dropdown is retried, and a dropdown that closes before its option is listed (a form
  re-rendering under the click) is opened again;
- a field re-rendered under the click is found again with the same locator;
- a field that never opens fails fast with `select2 dropdown did not open after 3 clicks on …`;
- results that load slowly are waited for ("Searching…"), within `Capybara.default_max_wait_time`.

## Installation

```ruby
group :test do
  gem 'capybara-select', require: 'capybara-select2'
end
```

The gem includes its helpers into every RSpec example. Outside RSpec (for example Cucumber), add
`include Capybara::Select2` to your support file.

## Usage

Locate the field by its label, the `for` of its label, CSS or XPath of the select2 container:

```ruby
select2('Banana', from: 'Fruit')
select2('Banana', field: 'fruit')
select2('Banana', css: '#question_12 .select2-container')
select2('Banana', xpath: container.path)
```

Options:

| Option | Default | |
|---|---|---|
| `mode:` | `:exact_text` | `:insensitive` matches part of the text (or a Regexp), `:case_insensitive` ignores case |
| `search: true` | | types the value into the search box first, for fields with a minimum input length |
| `await_option: true` | | polls for the option before reading the list (`max_retries:`, default 5) |
| `wait:` | | sleeps this many seconds before reading the list |

`select2_filter('an', from: 'Fruit', search: true)` returns the listed options without picking one.

For a field with [tags](https://select2.github.io/select2/#tags):

```ruby
select2_tag('value', from: 'Label of input')
```

## Development

    bundle install
    bundle exec rake          # RuboCop and the specs (headless Chrome, select2 4.0.13 and 3.5.4)

## Releasing

    rake "release:bump[minor]"   # bump version.rb, add a Changes.md section
    rake release:dry_run         # checks, lint, specs, package inspection; pushes nothing
    rake release                 # the same checks, then tag vX.Y.Z and push to rubygems.org

## License

MIT, see [LICENSE.txt](LICENSE.txt). Original author: William Yeung.
