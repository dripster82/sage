# frozen_string_literal: true

module PromptFlowServices
  class OutputNodeService < BaseNodeService
    def execute
      output_keys = port_keys(node.input_ports)
      output_keys.each do |port|
        node_state[port] = inputs[port]
        outputs_hash[port] = inputs[port]
      end

      node_state
    end

    private

    def outputs_hash
      state[:outputs] ||= {}
    end
  end
end
