# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin AI Logs', type: :request do
  let!(:admin_user) { create(:admin_user) }
  let!(:allowed_model) { create(:allowed_model, model: 'x-ai/grok-code-fast-1', active: true, default: true) }
  let!(:ai_log) { create(:ai_log, model: 'x-ai/grok-code-fast-1', query: 'What is 2+2?') }

  before do
    sign_in admin_user, scope: :admin_user
  end

  describe 'POST /admin/ai_logs/model_test' do
    context 'with valid parameters' do
      it 'executes a model test successfully' do
        # Mock the Llm::QueryService
        mock_response = double(
          'Response',
          content: 'The answer is 4.',
          input_tokens: 10,
          output_tokens: 5
        )

        allow_any_instance_of(Llm::QueryService).to receive(:ask).and_return(mock_response)

        post '/admin/ai_logs/model_test', params: {
          model: 'x-ai/grok-code-fast-1',
          query: 'What is 2+2?'
        }, headers: { 'X-Requested-With' => 'XMLHttpRequest' }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['response']).to eq('The answer is 4.')
        expect(json_response['model']).to eq('x-ai/grok-code-fast-1')
        expect(json_response['input_tokens']).to eq(10)
        expect(json_response['output_tokens']).to eq(5)
        expect(json_response).to have_key('processing_time')
      end

      it 'sets the ailog_session to ADMIN_TEST' do
        mock_response = double(
          'Response',
          content: 'Test response',
          input_tokens: 5,
          output_tokens: 3
        )

        allow_any_instance_of(Llm::QueryService).to receive(:ask) do
          expect(Current.ailog_session).to eq('ADMIN_TEST')
          mock_response
        end

        post '/admin/ai_logs/model_test', params: {
          model: 'x-ai/grok-code-fast-1',
          query: 'Test query'
        }, headers: { 'X-Requested-With' => 'XMLHttpRequest' }

        expect(Current.ailog_session).to be_nil
      end

      it 'creates a QueryService with correct parameters' do
        expect(Llm::QueryService).to receive(:new).with(
          model: 'x-ai/grok-code-fast-1',
          temperature: 0.7
        ).and_call_original

        mock_response = double(
          'Response',
          content: 'Response',
          input_tokens: 5,
          output_tokens: 3
        )

        allow_any_instance_of(Llm::QueryService).to receive(:ask).and_return(mock_response)

        post '/admin/ai_logs/model_test', params: {
          model: 'x-ai/grok-code-fast-1',
          query: 'Test query'
        }, headers: { 'X-Requested-With' => 'XMLHttpRequest' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with error handling' do
      it 'returns error status when service raises an exception' do
        allow_any_instance_of(Llm::QueryService).to receive(:ask).and_raise(StandardError, 'API Error')

        post '/admin/ai_logs/model_test', params: {
          model: 'x-ai/grok-code-fast-1',
          query: 'Test query'
        }, headers: { 'X-Requested-With' => 'XMLHttpRequest' }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('API Error')
      end

      it 'cleans up ailog_session even on error' do
        allow_any_instance_of(Llm::QueryService).to receive(:ask).and_raise(StandardError, 'Test error')

        post '/admin/ai_logs/model_test', params: {
          model: 'x-ai/grok-code-fast-1',
          query: 'Test query'
        }, headers: { 'X-Requested-With' => 'XMLHttpRequest' }

        expect(Current.ailog_session).to be_nil
      end
    end
  end
end

