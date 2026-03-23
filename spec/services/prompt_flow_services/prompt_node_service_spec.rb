# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PromptFlowServices::PromptNodeService, type: :service do
  it 'calls PromptProcessingService and stores output' do
    prompt = create(:prompt, name: 'test_prompt')
    node = build(:prompt_flow_node, :prompt_node, prompt: prompt)
    state = {}
    inputs = { 'query' => 'hello', 'text' => 'world' }

    mock_response = double('Response')
    service_double = instance_double(PromptProcessingService)

    allow(PromptProcessingService).to receive(:new).and_return(service_double)
    allow(service_double).to receive(:process_and_query).and_return(
      response: mock_response
    )

    service = described_class.new(node: node, state: state, inputs: inputs)
    result = service.execute

    expect(service_double).to have_received(:process_and_query).with(
      prompt_key: 'test_prompt',
      query: 'hello',
      parameters: { 'text' => 'world' }
    )
    # The service returns node_state which has 'response' key when no output_ports are configured
    expect(result['response']).to eq(mock_response)
  end
end
