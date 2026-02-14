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

      node_state['output'] = result[:response]
      node_state
    end
  end
end
