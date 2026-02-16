# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PromptFlowExecutionContext, type: :service do
  it 'stringifies input keys and stores node/output values' do
    context = described_class.new(inputs: { query: 'hello', 'text' => 'world' })

    expect(context.inputs).to eq({ 'query' => 'hello', 'text' => 'world' })
    expect(context.input_for(:query)).to eq('hello')

    context.set_node_output(10, { output: 'ok' })
    expect(context.node_output(10)).to eq({ 'output' => 'ok' })

    context.set_output(:result, 'done')
    expect(context.output_for('result')).to eq('done')

    context.merge_outputs(status: 'complete')
    expect(context.outputs).to eq({ 'result' => 'done', 'status' => 'complete' })
  end
end
