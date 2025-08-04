# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!
require 'shoulda/matchers'
require 'factory_bot_rails'
require 'faker'
require 'webmock/rspec'
require 'vcr'
require 'database_cleaner/active_record'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Suppress JSON duplicate key warnings in test environment
# This prevents warnings from JSON.parse when LLM responses contain duplicate keys
if defined?(JSON)
  original_parse = JSON.method(:parse)
  JSON.define_singleton_method(:parse) do |source, opts = {}|
    opts = opts.merge(allow_duplicate_key: true) if opts.is_a?(Hash)
    original_parse.call(source, opts)
  end
end

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, type: :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/6-0/rspec-rails
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods

  # Include Rails time helpers
  config.include ActiveSupport::Testing::TimeHelpers

  # Database cleaner configuration
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  # Shoulda Matchers configuration
  Shoulda::Matchers.configure do |shoulda_config|
    shoulda_config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end

  # WebMock configuration - disable all external connections except localhost
  WebMock.disable_net_connect!(allow_localhost: true)

  # Stub external API requests
  WebMock.stub_request(:post, "https://api.openai.com/v1/embeddings")
    .to_return(status: 200, body: { data: [{ embedding: Array.new(1536) { rand } }] }.to_json)

  WebMock.stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
    .to_return(status: 200, body: { choices: [{ message: { content: "Mock response" } }] }.to_json)

  # Stub external services to prevent real API calls
  config.before(:each) do
    # Stub RubyLLM.embed to return mock embeddings
    allow(RubyLLM).to receive(:embed).and_return(Array.new(1536) { rand })

    # Stub RubyLLM.chat for chat completions - return a mock chat object
    mock_chat = double('RubyLLM Chat')
    allow(mock_chat).to receive(:with_temperature).and_return(mock_chat)
    allow(mock_chat).to receive(:ask).and_return(double(content: "Mock response", input_tokens: 10, output_tokens: 5))
    allow(mock_chat).to receive(:model).and_return(double(
      id: 'mock-model',
      provider: 'mock-provider',
      pricing: double(
        text_tokens: double(
          standard: double(
            input_per_million: 1000,
            output_per_million: 2000
          )
        )
      )
    ))
    allow(RubyLLM).to receive(:chat).and_return(mock_chat)
  end
end
