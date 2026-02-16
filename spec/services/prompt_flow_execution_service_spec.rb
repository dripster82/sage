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

  describe '#execute' do
    it 'executes a simple flow and records outputs' do
      flow = create(:prompt_flow)
      input_node = create(:prompt_flow_node,
                          prompt_flow: flow,
                          node_type: 'input',
                          output_ports: { 'query' => {}, 'text' => {} })
      prompt = create(:prompt, name: 'test_prompt')
      prompt_node = create(:prompt_flow_node,
                           prompt_flow: flow,
                           node_type: 'prompt',
                           prompt: prompt,
                           input_ports: { 'query' => {}, 'text' => {} },
                           output_ports: { 'output' => {} })
      output_node = create(:prompt_flow_node,
                           prompt_flow: flow,
                           node_type: 'output',
                           input_ports: { 'output' => {} })

      create(:prompt_flow_edge,
             prompt_flow: flow,
             source_node: input_node,
             target_node: prompt_node,
             source_port: 'query',
             target_port: 'query')
      create(:prompt_flow_edge,
             prompt_flow: flow,
             source_node: input_node,
             target_node: prompt_node,
             source_port: 'text',
             target_port: 'text')
      create(:prompt_flow_edge,
             prompt_flow: flow,
             source_node: prompt_node,
             target_node: output_node,
             source_port: 'output',
             target_port: 'output')

      mock_response = 'ok'
      service_double = instance_double(PromptProcessingService)
      allow(PromptProcessingService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:process_and_query).and_return(
        response: mock_response
      )

      execution = described_class.new(flow).execute(inputs: { 'query' => 'hello', 'text' => 'world' })

      expect(execution.status).to eq('completed')
      expect(execution.outputs).to eq({ 'output' => 'ok' })
      expect(execution.execution_log.size).to eq(3)
    end

    it 'fails when max execution limit is exceeded' do
      flow = create(:prompt_flow, max_executions: 1)
      input_node = create(:prompt_flow_node,
                          prompt_flow: flow,
                          node_type: 'input',
                          output_ports: { 'query' => {} })
      prompt = create(:prompt, name: 'test_prompt')
      prompt_node = create(:prompt_flow_node,
                           prompt_flow: flow,
                           node_type: 'prompt',
                           prompt: prompt,
                           input_ports: { 'query' => {} },
                           output_ports: { 'output' => {} })

      create(:prompt_flow_edge,
             prompt_flow: flow,
             source_node: input_node,
             target_node: prompt_node,
             source_port: 'query',
             target_port: 'query')

      service_double = instance_double(PromptProcessingService)
      allow(PromptProcessingService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:process_and_query).and_return(
        response: 'ok'
      )

      expect { described_class.new(flow).execute(inputs: { 'query' => 'hi' }) }
        .to raise_error(PromptFlowExecutionService::ExecutionLimitError)
    end

    it 'stores partial output when execution limit is hit after upstream nodes ran' do
      flow = create(:prompt_flow, max_executions: 2)
      input_node = create(:prompt_flow_node,
                          prompt_flow: flow,
                          node_type: 'input',
                          output_ports: { 'query' => {} })
      prompt = create(:prompt, name: 'test_prompt')
      prompt_node = create(:prompt_flow_node,
                           prompt_flow: flow,
                           node_type: 'prompt',
                           prompt: prompt,
                           input_ports: { 'query' => {} },
                           output_ports: { 'output' => {}, 'flow' => {} })
      output_node = create(:prompt_flow_node,
                           prompt_flow: flow,
                           node_type: 'output',
                           input_ports: { 'output' => {}, 'flow' => {} })

      create(:prompt_flow_edge,
             prompt_flow: flow,
             source_node: input_node,
             target_node: prompt_node,
             source_port: 'query',
             target_port: 'query')
      create(:prompt_flow_edge,
             prompt_flow: flow,
             source_node: prompt_node,
             target_node: output_node,
             source_port: 'output',
             target_port: 'output')
      create(:prompt_flow_edge,
             prompt_flow: flow,
             source_node: prompt_node,
             target_node: output_node,
             source_port: 'flow',
             target_port: 'flow')

      service_double = instance_double(PromptProcessingService)
      allow(PromptProcessingService).to receive(:new).and_return(service_double)
      allow(service_double).to receive(:process_and_query).and_return(response: 'partial-ok')

      expect { described_class.new(flow).execute(inputs: { 'query' => 'hi' }) }
        .to raise_error(PromptFlowExecutionService::ExecutionLimitError)

      execution = flow.executions.order(:id).last
      expect(execution.status).to eq('failed')
      expect(execution.outputs).to eq({ 'output' => 'partial-ok' })
    end
  end
end
