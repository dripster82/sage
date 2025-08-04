# frozen_string_literal: true

source "https://rubygems.org"

ruby "3.4.4"

gem "rails", "~> 8.0.2"
gem "sqlite3"
gem "puma"
gem "pg"

gem "sprockets-rails"
gem "cssbundling-rails"
gem "importmap-rails"

gem "activeadmin", "4.0.0.beta15" # github: "activeadmin/activeadmin", branch: "master"
gem "devise"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]

  # RSpec testing framework
  gem "rspec-rails", "~> 6.0"
  gem "factory_bot_rails", "~> 6.2"
  gem "faker", "~> 3.2"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
  gem "simplecov", require: false
  gem "simplecov-cobertura"
  gem "rails-controller-testing"

  # Additional RSpec testing gems
  gem "shoulda-matchers", "~> 5.3"
  gem "webmock", "~> 3.18"
  gem "vcr", "~> 6.2"
  gem "database_cleaner-active_record", "~> 2.1"
end

gem "pdf-reader", "~> 2.0"

gem "mime-types", "~> 3.7"

gem "ruby_llm", "~> 1.3"

gem "baran", "~> 0.2.1"



gem "activegraph", "= 12.0.0.beta4"

gem "json-repair", "~> 0.2.0"
