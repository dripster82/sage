# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API V1 UserPromptFlows', type: :request do
  let(:user) { create(:user, credits: 10) }
  let(:auth_token) { Users::TokenService.encode_user_token(user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{auth_token}" } }
  let(:flow) { create(:prompt_flow, name: 'flow_a', is_current: true, credits: 3) }

  describe 'POST /api/v1/prompt_flows/process' do
    it 'executes current flow by name and deducts credits' do
      execution = create(:prompt_flow_execution, prompt_flow: flow, status: 'completed', outputs: { 'response' => 'ok' })
      validator = instance_double(PromptFlowValidationService, call: [])
      executor = instance_double(PromptFlowExecutionService, execute: execution)

      allow(PromptFlowValidationService).to receive(:new).with(flow).and_return(validator)
      allow(PromptFlowExecutionService).to receive(:new).with(flow).and_return(executor)

      post '/api/v1/prompt_flows/process', params: { prompt_flow: flow.name, text: 'hello' }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json.dig('data', 'outputs')).to eq({ 'response' => 'ok' })
      expect(json.dig('data', 'cost')).to eq(3)
      expect(user.reload.credits).to eq(7)
    end

    it 'returns payment required when user has insufficient credits' do
      user.update!(credits: 1)
      validator = instance_double(PromptFlowValidationService, call: [])
      allow(PromptFlowValidationService).to receive(:new).with(flow).and_return(validator)
      expect(PromptFlowExecutionService).not_to receive(:new)

      post '/api/v1/prompt_flows/process', params: { prompt_flow: flow.name, text: 'hello' }, headers: headers

      expect(response).to have_http_status(:payment_required)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
      expect(json['error']).to match(/Insufficient credits/)
    end

    it 'returns validation errors for invalid flow' do
      validator = instance_double(PromptFlowValidationService, call: [{ type: 'missing_input', message: 'x' }])
      allow(PromptFlowValidationService).to receive(:new).with(flow).and_return(validator)
      expect(PromptFlowExecutionService).not_to receive(:new)

      post '/api/v1/prompt_flows/process', params: { prompt_flow: flow.name }, headers: headers

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
      expect(json['details']).to eq([{ 'type' => 'missing_input', 'message' => 'x' }])
    end

    it 'returns not found for missing current flow name' do
      post '/api/v1/prompt_flows/process', params: { prompt_flow: 'missing_flow' }, headers: headers

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
      expect(json['error']).to eq('Prompt flow not found: missing_flow')
    end

    it 'returns bad request when prompt_flow param is missing' do
      post '/api/v1/prompt_flows/process', params: { text: 'hello' }, headers: headers

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
      expect(json['error']).to eq('Prompt flow parameter is required')
    end
  end
end
