# frozen_string_literal: true

class PromptProcessingService
  # Custom error classes
  class PromptNotFoundError < StandardError; end

  attr_reader :temperature, :model

  def initialize(temperature: 0.7, model: nil)
    @temperature = temperature
    @model = model
  end

  def process_and_query(prompt_key: nil, query: nil, parameters: {}, chat_id: nil)
    validate_parameters({ prompt_key: prompt_key, query: query })

    prompt = find_prompt(prompt_key)
    processed_prompt = build_processed_prompt(prompt, query, parameters)

    # Use the existing LLM QueryService for the actual query
    llm_service = Llm::QueryService.new(temperature: @temperature, model: @model)
    response = llm_service.ask(processed_prompt, chat_id: chat_id)

    {
      processed_prompt: processed_prompt,
      original_query: query,
      prompt: prompt,
      response: response,
      ai_log: llm_service.ai_log
    }
  end

  def process_and_query_json(prompt_key: nil, query: nil, parameters: {}, chat_id: nil)
    validate_parameters({ prompt_key: prompt_key, query: query })

    prompt = find_prompt(prompt_key)
    processed_prompt = build_processed_prompt(prompt, query, parameters)

    # Use the existing LLM QueryService for JSON responses
    llm_service = Llm::QueryService.new(temperature: @temperature, model: @model)
    response = llm_service.json_from_query(processed_prompt, chat_id: chat_id)

    {
      processed_prompt: processed_prompt,
      original_query: query,
      prompt: prompt,
      response: response,
      ai_log: llm_service.ai_log
    }
  end

  private

  def validate_parameters(params)
    raise MissingParameterError, 'Prompt key is required' if params[:prompt_key].blank?
  end

  def find_prompt(prompt_key)
    prompt = Prompt.find_by(name: prompt_key)
    raise PromptNotFoundError, "Prompt not found: #{prompt_key}" unless prompt
    prompt
  end

  def build_processed_prompt(prompt, query, parameters)
    # Follow the existing pattern from llm_extraction_service and llm_validation_service
    replacement_hash = prompt.tags_hash.tap do |h|
      h[:query] = query
      # Merge in the additional parameters provided
      parameters.each do |key, value|
        h[key.to_sym] = value
      end
    end

    prompt.content % replacement_hash
  end
end
