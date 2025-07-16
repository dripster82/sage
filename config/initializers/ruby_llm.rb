# config/initializers/ruby_llm.rb (in Rails) or at the start of your script
require 'ruby_llm'

RubyLLM.configure do |config|
  config.openrouter_api_key = ENV.fetch('OPENROUTER_API_KEY', nil)
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)

  config.default_model = 'google/gemini-2.5-flash' #'google/gemini-2.0-flash-001'
  config.default_embedding_model = 'text-embedding-ada-002'

end

RubyLLM.models.refresh!
