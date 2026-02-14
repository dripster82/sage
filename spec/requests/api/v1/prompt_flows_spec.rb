# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API V1 PromptFlows', type: :request do
  let(:admin_user) { create(:admin_user) }
  let(:auth_token) { AdminUsers::TokenService.encode_user_token(admin_user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{auth_token}" } }

  describe 'POST /api/v1/prompt_flows' do
    it 'creates a prompt flow with nodes and edges' do
      prompt = create(:prompt, name: 'test_prompt')

      payload = {
        prompt_flow: {
          name: 'Flow A',
          description: 'Test flow',
          status: 'draft',
          version_number: 1,
          is_current: true,
          max_executions: 20
        },
        nodes: [
          {
            temp_id: 'n1',
            node_type: 'input',
            position_x: 10,
            position_y: 20,
            output_ports: { 'query' => {} }
          },
          {
            temp_id: 'n2',
            node_type: 'prompt',
            prompt_id: prompt.id,
            input_ports: { 'query' => {} },
            output_ports: { 'output' => {} }
          },
          {
            temp_id: 'n3',
            node_type: 'output',
            input_ports: { 'output' => {} }
          }
        ],
        edges: [
          {
            source_node_temp_id: 'n1',
            target_node_temp_id: 'n2',
            source_port: 'query',
            target_port: 'query'
          },
          {
            source_node_temp_id: 'n2',
            target_node_temp_id: 'n3',
            source_port: 'output',
            target_port: 'output'
          }
        ]
      }

      post '/api/v1/prompt_flows', params: payload, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json.dig('data', 'prompt_flow', 'name')).to eq('Flow A')
      expect(json.dig('data', 'nodes').size).to eq(3)
      expect(json.dig('data', 'edges').size).to eq(2)
    end
  end

  describe 'GET /api/v1/prompt_flows/:id' do
    it 'returns the prompt flow graph' do
      flow = create(:prompt_flow, name: 'Flow B')
      create(:prompt_flow_node, prompt_flow: flow)

      get "/api/v1/prompt_flows/#{flow.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json.dig('data', 'prompt_flow', 'name')).to eq('Flow B')
      expect(json.dig('data', 'nodes').size).to eq(1)
    end
  end

  describe 'PUT /api/v1/prompt_flows/:id' do
    it 'replaces nodes and edges' do
      flow = create(:prompt_flow, name: 'Flow C')
      create(:prompt_flow_node, prompt_flow: flow)

      payload = {
        prompt_flow: {
          name: 'Flow C',
          description: 'Updated',
          status: 'draft',
          version_number: 1,
          is_current: true,
          max_executions: 20
        },
        nodes: [
          {
            temp_id: 'n1',
            node_type: 'input',
            output_ports: { 'query' => {} }
          }
        ],
        edges: []
      }

      put "/api/v1/prompt_flows/#{flow.id}", params: payload, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json.dig('data', 'nodes').size).to eq(1)
      expect(flow.reload.nodes.count).to eq(1)
    end

    it 'handles edges sent as indexed hash payload' do
      flow = create(:prompt_flow, name: 'Flow D')
      prompt = create(:prompt, name: 'test_prompt')

      payload = {
        prompt_flow: {
          name: 'Flow D',
          description: 'Updated',
          status: 'draft',
          version_number: 1,
          is_current: true,
          max_executions: 20
        },
        nodes: {
          '0' => {
            temp_id: 'n1',
            node_type: 'input',
            output_ports: { 'query' => {} }
          },
          '1' => {
            temp_id: 'n2',
            node_type: 'prompt',
            prompt_id: prompt.id,
            input_ports: { 'query' => {} },
            output_ports: { 'output' => {} }
          }
        },
        edges: {
          '0' => {
            source_node_temp_id: 'n1',
            target_node_temp_id: 'n2',
            source_port: 'query',
            target_port: 'query'
          }
        }
      }

      put "/api/v1/prompt_flows/#{flow.id}", params: payload, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json.dig('data', 'edges').size).to eq(1)
    end

    it 'ignores invalid edge entries in payload' do
      flow = create(:prompt_flow, name: 'Flow E')
      prompt = create(:prompt, name: 'test_prompt')

      payload = {
        prompt_flow: {
          name: 'Flow E',
          description: 'Updated',
          status: 'draft',
          version_number: 1,
          is_current: true,
          max_executions: 20
        },
        nodes: [
          {
            temp_id: 'n1',
            node_type: 'input',
            output_ports: { 'query' => {} }
          },
          {
            temp_id: 'n2',
            node_type: 'prompt',
            prompt_id: prompt.id,
            input_ports: { 'query' => {} },
            output_ports: { 'output' => {} }
          }
        ],
        edges: [
          'invalid',
          {
            source_node_temp_id: 'n1',
            target_node_temp_id: 'n2',
            source_port: 'query',
            target_port: 'query'
          }
        ]
      }

      put "/api/v1/prompt_flows/#{flow.id}", params: payload, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json.dig('data', 'edges').size).to eq(1)
    end
  end

  describe 'POST /api/v1/prompt_flows/:id/execute' do
    it 'executes the flow and returns outputs' do
      flow = create(:prompt_flow)
      execution = create(:prompt_flow_execution, prompt_flow: flow, status: 'completed', outputs: { 'output' => 'ok' })

      validator = instance_double(PromptFlowValidationService, call: [])
      executor = instance_double(PromptFlowExecutionService, execute: execution)

      allow(PromptFlowValidationService).to receive(:new).with(flow).and_return(validator)
      allow(PromptFlowExecutionService).to receive(:new).with(flow).and_return(executor)

      post "/api/v1/prompt_flows/#{flow.id}/execute", params: { inputs: { 'query' => 'hi' } }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json.dig('data', 'outputs')).to eq({ 'output' => 'ok' })
    end
  end

  describe 'GET /api/v1/prompt_flows/:prompt_flow_id/executions' do
    it 'lists executions for a flow' do
      flow = create(:prompt_flow)
      exec1 = create(:prompt_flow_execution, prompt_flow: flow)
      exec2 = create(:prompt_flow_execution, prompt_flow: flow)

      get "/api/v1/prompt_flows/#{flow.id}/executions", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json.dig('data', 'executions').size).to eq(2)
      ids = json.dig('data', 'executions').map { |e| e['id'] }
      expect(ids).to include(exec1.id, exec2.id)
    end
  end

  describe 'GET /api/v1/prompt_flows/:prompt_flow_id/executions/:id' do
    it 'returns a single execution' do
      flow = create(:prompt_flow)
      execution = create(:prompt_flow_execution, prompt_flow: flow, status: 'completed', outputs: { 'output' => 'ok' })

      get "/api/v1/prompt_flows/#{flow.id}/executions/#{execution.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json.dig('data', 'execution', 'id')).to eq(execution.id)
      expect(json.dig('data', 'execution', 'outputs')).to eq({ 'output' => 'ok' })
    end
  end
end
