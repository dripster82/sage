# frozen_string_literal: true

module PromptFlowServices
  class BaseNodeService
    def initialize(node:, state:, inputs: {})
      @node = node
      @state = state
      @inputs = inputs
    end

    def execute
      raise NotImplementedError
    end

    private

    attr_reader :node, :state, :inputs

    def node_state
      state[node.id] ||= {}
    end

    def port_keys(ports)
      case ports
      when Hash
        ports.keys.map(&:to_s)
      when Array
        ports.map(&:to_s)
      when String
        [ports]
      else
        []
      end
    end
  end
end
