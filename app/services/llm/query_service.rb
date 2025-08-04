# frozen_string_literal: true

module Llm
  class QueryService
    attr_reader :temperature, :model, :ai_log

    def initialize(temperature: 0.7, model: nil)
      @temperature = temperature
      @model = model || RubyLLM.config.default_model
    end

    def chat
      @chat ||= RubyLLM.chat(model: @model).with_temperature(@temperature)
    end

    def ask(query, chat_id: nil)
      # Create the AI log entry first
      @ai_log = create_log_entry(query, chat_id)

      begin
        # Make the LLM request
        response = chat.ask(query)

        # Update the log with response data
        update_log_with_response(response)

        response
      rescue => e
        # Update log with error information
        update_log_with_error(e)
        raise e
      end
    end


    def  json_from_query(query, chat_id: nil)
      response = ask(query, chat_id: chat_id)
      JSON.parse(JSON.repair(strip_formatting(response.content)))
    end

    private

    def strip_formatting(str)
      str_array = str.split("\n")
      str_array =  str_array[1..-2] if str_array.first.include?("```")

      first_idx = ["{", "["].include?(str_array.first) ? 0 : 1
      last_idx = ["}", "]"].include?(str_array.last)  ? -1 : -2
      
      str_array[first_idx..last_idx].join("\n") 
    end

    def create_log_entry(query, chat_id)
      AiLog.create!(
        model: @model,
        query: query,
        chat_id: chat_id,
        session_uuid: Current.ailog_session,
        settings: {
          temperature: @temperature,
          model: @model
        }
      )
    end

    def update_log_with_response(response)
      per_token_in = chat.model.pricing.text_tokens.standard.input_per_million.to_f / 1000000
      per_token_out = chat.model.pricing.text_tokens.standard.output_per_million.to_f / 1000000
      price_in = (response.input_tokens * per_token_in)
      price_out = (response.output_tokens * per_token_out)
      @ai_log.update!(
        response: response.content,
        input_tokens: response.input_tokens,
        output_tokens: response.output_tokens,
        total_cost: price_in + price_out,
        settings: @ai_log.settings.merge({
          temperature: @temperature,
          model:  chat.model.id,
          provider: chat.model.provider,
          cost_in: price_in,
          cost_out: price_out,
          cost_total: price_in + price_out
        })
      )
    end

    def update_log_with_error(error)
      @ai_log.update!(
        response: "ERROR: #{error.message}",
        settings: @ai_log.settings.merge({
          temperature: @temperature,
          model: @model,
          error: error.message,
          error_class: error.class.name
        })
      )
    end
  end
end