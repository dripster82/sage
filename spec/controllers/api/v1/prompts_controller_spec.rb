# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::PromptsController, type: :controller do
  let(:mock_service) { double('PromptProcessingService') }
  let(:mock_response) { double('Response', content: 'LLM response content') }
  let(:mock_ai_log) { double('AiLog', id: 1) }
  let(:mock_prompt) { double('Prompt', name: 'test_prompt') }
  let(:admin_user) { create(:admin_user) }
  let(:valid_token) { AdminUsers::TokenService.encode_user_token(admin_user.id) }

  let(:service_result) do
    {
      processed_prompt: 'Hello John, your query is: What is my status?',
      original_query: 'What is my status?',
      prompt: mock_prompt,
      response: mock_response,
      ai_log: mock_ai_log
    }
  end

  before do
    allow(PromptProcessingService).to receive(:new).and_return(mock_service)
    allow(mock_service).to receive(:process_and_query).and_return(service_result)
  end

  describe 'authentication' do
    let(:valid_params) do
      {
        prompt: 'test_prompt',
        query: 'What is my status?',
        name: 'John',
        age: '25'
      }
    end

    context 'without JWT token' do
      it 'returns unauthorized error' do
        post :process_prompt, params: valid_params, format: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Token not provided')
      end
    end

    context 'with invalid JWT token' do
      before do
        request.headers['Authorization'] = 'Bearer invalid-token'
      end

      it 'returns unauthorized error' do
        post :process_prompt, params: valid_params, format: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid token')
      end
    end

    context 'with valid JWT token' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'allows access to the endpoint' do
        post :process_prompt, params: valid_params, format: :json

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'POST #process_prompt' do
    let(:valid_params) do
      {
        prompt: 'test_prompt',
        query: 'What is my status?',
        name: 'John',
        age: '25'
      }
    end

    before do
      # Set valid JWT token for all tests in this context
      request.headers['Authorization'] = "Bearer #{valid_token}"
    end

    context 'with valid parameters' do
      it 'processes the prompt and returns success response' do
        post :process_prompt, params: valid_params, format: :json

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['data']['response']).to eq('LLM response content')
        expect(json_response['data']['prompt_name']).to eq('test_prompt')
        expect(json_response['data']['original_query']).to eq('What is my status?')
      end

      it 'calls the processing service with correct parameters' do
        expect(mock_service).to receive(:process_and_query).with(
          prompt_key: 'test_prompt',
          query: 'What is my status?',
          parameters: { 'name' => 'John', 'age' => '25' },
          chat_id: nil
        )

        post :process_prompt, params: valid_params, format: :json
      end

      it 'passes chat_id when provided' do
        params_with_chat_id = valid_params.merge(chat_id: 'test-chat-123')
        
        expect(mock_service).to receive(:process_and_query).with(
          prompt_key: 'test_prompt',
          query: 'What is my status?',
          parameters: { 'name' => 'John', 'age' => '25' },
          chat_id: 'test-chat-123'
        )

        post :process_prompt, params: params_with_chat_id, format: :json
      end

      it 'handles optional temperature parameter' do
        params_with_temp = valid_params.merge(temperature: 0.5)

        expect(PromptProcessingService).to receive(:new).with(temperature: 0.5, model: nil)

        post :process_prompt, params: params_with_temp, format: :json
      end

      it 'handles optional model parameter' do
        params_with_model = valid_params.merge(model: 'gpt-4')

        expect(PromptProcessingService).to receive(:new).with(temperature: 0.7, model: 'gpt-4')

        post :process_prompt, params: params_with_model, format: :json
      end
    end

    context 'with missing required parameters' do
      it 'returns error when prompt is missing' do
        invalid_params = valid_params.except(:prompt)
        
        post :process_prompt, params: invalid_params, format: :json

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Prompt parameter is required')
      end

      it 'returns error when query is missing' do
        invalid_params = valid_params.except(:query)

        post :process_prompt, params: invalid_params, format: :json
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Query parameter is required')
      end
    end

    context 'when service raises errors' do
      it 'handles PromptNotFoundError' do
        allow(mock_service).to receive(:process_and_query)
          .and_raise(PromptProcessingService::PromptNotFoundError, 'Prompt not found: invalid_prompt')
        
        post :process_prompt, params: valid_params, format: :json

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Prompt not found: invalid_prompt')
      end

      it 'handles MissingParameterError' do
        allow(mock_service).to receive(:process_and_query)
          .and_raise(PromptProcessingService::MissingParameterError, 'Query is required')

        post :process_prompt, params: valid_params, format: :json

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Query is required')
      end

      it 'handles general StandardError' do
        allow(mock_service).to receive(:process_and_query)
          .and_raise(StandardError, 'Something went wrong')

        post :process_prompt, params: valid_params, format: :json
        
        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Internal server error')
      end
    end
  end
end
