# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PromptFlowServices::InputNodeService, type: :service do
  it 'writes inputs to node state based on output ports' do
    node = build(:prompt_flow_node, output_ports: { 'text' => {}, 'query' => {} })
    state = {}
    inputs = { 'text' => 'hello', 'query' => 'world' }

    service = described_class.new(node: node, state: state, inputs: inputs)
    result = service.execute

    expect(result).to eq({ 'text' => 'hello', 'query' => 'world' })
    expect(state[node.id]).to eq({ 'text' => 'hello', 'query' => 'world' })
  end
end
