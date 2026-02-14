# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PromptFlowExecutionService, type: :service do
  describe '#topological_sort' do
    it 'returns nodes in topological order for a simple chain' do
      flow = create(:prompt_flow)
      node_a = create(:prompt_flow_node, prompt_flow: flow)
      node_b = create(:prompt_flow_node, :prompt_node, prompt_flow: flow)
      node_c = create(:prompt_flow_node, :output_node, prompt_flow: flow)

      create(:prompt_flow_edge,
             prompt_flow: flow,
             source_node: node_a,
             target_node: node_b,
             source_port: 'out',
             target_port: 'in')

      create(:prompt_flow_edge,
             prompt_flow: flow,
             source_node: node_b,
             target_node: node_c,
             source_port: 'out',
             target_port: 'in')

      ordered = described_class.new(flow).topological_sort

      expect(ordered.map(&:id)).to eq([node_a.id, node_b.id, node_c.id])
    end

    it 'raises when a cycle is detected' do
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

      expect { described_class.new(flow).topological_sort }
        .to raise_error(PromptFlowExecutionService::CycleDetectedError)
    end
  end
end
