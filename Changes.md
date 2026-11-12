# capybara-select Changes

1.0.0
---------

First release of this fork under its own name, `capybara-select`; `capybara-select2` on rubygems.org is the
original (1.0.1, 2015). Keep `require 'capybara-select2'` and `Capybara::Select2`.

- A click that does not open the dropdown is retried (3 clicks), so a field that re-renders under the click, or a
  dropdown that closes straight away, still gets its option picked.
- A dropdown that closes before the option is listed (a lookup re-rendering the form) is opened again.
- A field re-rendered under the click (`StaleElementReferenceError`) is found again with the same locator.
- A field that never opens fails fast with `select2 dropdown did not open after 3 clicks on …`, instead of waiting
  `default_max_wait_time` several times and reporting missing 3.x `li.select2-result-selectable` options. The
  select2 version is read from the field, not from the dropdown.
- `search: true` and the "Searching…" wait no longer spend a full `default_max_wait_time` when nothing is loading,
  and every wait is bounded.
- Fix: `from:` with select2 3.x matched both the label and select2's off-screen copy of it.
- Fix: `Capybara::Ambiguous` reported the number of listed options, not of matches.
- `search: true` works with select2 3.x.
- Private helpers are prefixed with `select2_` (`select2_find_and_open`, `select2_fetch_options`, …). They are mixed
  into every example, so a spec helper with 1.0.4's names (`find_select2_and_open`, `open_select2`,
  `find_select2_container`, `fetch_options`) used to replace them. Call `select2` instead of those helpers.
- `css:` and `xpath:` may point at an element wrapping the select2 container, such as a form field.
- Removed `lib/capybara/select2.rb`, which could not be loaded.
- Specs against select2 4.0.13 and 3.5.4 in headless Chrome. Requires Ruby >= 3.2, Capybara 3 and
  selenium-webdriver 4. Packages only files committed to git. Release tasks in `rakelib/release.rake`.

1.0.4 (fork, never published)
---------

- `mode:` (`:exact_text`, `:insensitive`, `:case_insensitive`), `await_option:`, `max_retries:` and retries while
  select2 shows "Searching…".
- `wait:` to sleep before reading options (was `sleep:`).
