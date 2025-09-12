# config/initializers/ruby_llm.rb (in Rails) or at the start of your script
require 'ruby_llm'

RubyLLM.configure do |config|
  config.openrouter_api_key = ENV.fetch('OPENROUTER_API_KEY', nil)
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)

  # config.default_model = 'google/gemini-2.5-flash' 
  config.default_model = 'x-ai/grok-code-fast-1'
  # config.default_model = 'anthropic/claude-3.7-sonnet:thinking'
  config.default_embedding_model = 'text-embedding-ada-002'

end

RubyLLM.models.refresh!
