# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PromptFlowValidationService, type: :service do
  describe '#call' do
    it 'returns error when edge references missing port' do
      flow = create(:prompt_flow)
      source = create(:prompt_flow_node, prompt_flow: flow, output_ports: { 'out' => {} })
      target = create(:prompt_flow_node, :output_node, prompt_flow: flow, input_ports: { 'in' => {} })
      edge = create(:prompt_flow_edge,
                    prompt_flow: flow,
                    source_node: source,
                    target_node: target,
                    source_port: 'missing',
                    target_port: 'in')

      errors = described_class.new(flow).call

      expect(errors.map { |e| e[:type] }).to include(:port_missing_on_node)
      expect(errors.any? { |e| e[:data][:edge_id] == edge.id }).to be true
    end

    it 'returns error when required input is not connected' do
      flow = create(:prompt_flow)
      node = create(:prompt_flow_node,
                    prompt_flow: flow,
                    input_ports: { 'required_input' => { 'required' => true } })

      errors = described_class.new(flow).call

      expect(errors.map { |e| e[:type] }).to include(:required_input_missing)
      expect(errors.any? { |e| e[:data][:node_id] == node.id && e[:data][:port] == 'required_input' }).to be true
    end

    it 'detects cycles' do
      flow = create(:prompt_flow)
      node_a = create(:prompt_flow_node, prompt_flow: flow)
      node_b = create(:prompt_flow_node, :output_node, prompt_flow: flow)

      create(:prompt_flow_edge,
             prompt_flow: flow,
             source_node: node_a,
             target_node: node_b,
             source_port: 'out',
             target_port: 'in')

      create(:prompt_flow_edge,
             prompt_flow: flow,
             source_node: node_b,
             target_node: node_a,
             source_port: 'out',
             target_port: 'in')

      errors = described_class.new(flow).call

      expect(errors.map { |e| e[:type] }).to include(:cycle_detected)
      cycle = errors.find { |e| e[:type] == :cycle_detected }
      expect(cycle[:data][:node_ids]).to include(node_a.id, node_b.id)
    end

    it 'returns error when edge nodes belong to another flow' do
      flow = create(:prompt_flow)
      other_flow = create(:prompt_flow)
      source = create(:prompt_flow_node, prompt_flow: other_flow)
      target = create(:prompt_flow_node, :output_node, prompt_flow: flow)

      edge = build(:prompt_flow_edge,
                   prompt_flow: flow,
                   source_node: source,
                   target_node: target,
                   source_port: 'out',
                   target_port: 'in')
      edge.save!(validate: false)

      errors = described_class.new(flow).call

      expect(errors.map { |e| e[:type] }).to include(:edge_missing_node)
    end

    it 'allows flow control edges for prompt/output nodes without explicit flow ports' do
      flow = create(:prompt_flow)
      prompt = create(:prompt)
      prompt_node = create(:prompt_flow_node,
                           :prompt_node,
                           prompt_flow: flow,
                           prompt: prompt,
                           input_ports: { 'query' => {} },
                           output_ports: { 'response' => {} })
      output_node = create(:prompt_flow_node,
                           :output_node,
                           prompt_flow: flow,
                           input_ports: { 'response' => {} },
                           output_ports: {})

      create(:prompt_flow_edge,
             prompt_flow: flow,
             source_node: prompt_node,
             target_node: output_node,
             source_port: 'flow',
             target_port: 'flow')

      errors = described_class.new(flow).call

      expect(errors.map { |e| e[:type] }).not_to include(:port_missing_on_node)
    end
  end
end
