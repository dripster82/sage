# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PromptFlowServices::OutputNodeService, type: :service do
  it 'writes inputs to node state and outputs hash' do
    node = build(:prompt_flow_node, :output_node, input_ports: { 'result' => {}, 'summary' => {} })
    state = {}
    inputs = { 'result' => 'ok', 'summary' => 'done' }

    service = described_class.new(node: node, state: state, inputs: inputs)
    result = service.execute

    expect(result).to eq({ 'result' => 'ok', 'summary' => 'done' })
    expect(state[node.id]).to eq({ 'result' => 'ok', 'summary' => 'done' })
    expect(state[:outputs]).to eq({ 'result' => 'ok', 'summary' => 'done' })
  end
end
