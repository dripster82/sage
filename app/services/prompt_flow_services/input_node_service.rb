# frozen_string_literal: true

module PromptFlowServices
  class InputNodeService < BaseNodeService
    def execute
      output_ports = port_keys(node.output_ports)
      output_ports.each do |port|
        node_state[port] = inputs[port]
      end

      node_state
    end
  end
end
