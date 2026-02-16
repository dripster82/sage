# frozen_string_literal: true

module PromptFlowServices
  class PromptNodeService < BaseNodeService
    def execute
      prompt_key = node.prompt&.name
      query = inputs['query']
      parameters = inputs.reject { |key, _| key.to_s == 'query' }

      result = PromptProcessingService.new.process_and_query(
        prompt_key: prompt_key,
        query: query,
        parameters: parameters
      )

      response_value = extract_response_value(result[:response])

      # Respect configured output ports so graph edges can reference names like "response".
      output_ports = port_keys(node.output_ports)
      if output_ports.empty?
        node_state['response'] = response_value
      else
        output_ports.each { |port| node_state[port] = response_value }
      end

      if result[:ai_log].present?
        node_state['_prompt_metrics'] = {
          ai_log_id: result[:ai_log].id,
          input_tokens: result[:ai_log].input_tokens.to_i,
          output_tokens: result[:ai_log].output_tokens.to_i,
          total_cost: result[:ai_log].read_attribute(:total_cost).to_f
        }
      end
      node_state
    end

    private

    def extract_response_value(response)
      return response.content if response.respond_to?(:content)
      return response['content'] if response.is_a?(Hash) && response.key?('content')
      return response[:content] if response.is_a?(Hash) && response.key?(:content)

      response
    end
  end
end
