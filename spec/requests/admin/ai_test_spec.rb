# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin AI Test AJAX Endpoints', type: :request do
  let!(:admin_user) { create(:admin_user) }
  let!(:allowed_model) { create(:allowed_model, model: 'x-ai/grok-code-fast-1', active: true, default: true) }
  let!(:prompt) { create(:prompt, name: 'test_prompt', tags: ['text', 'topic'].to_json, status: 'active') }

  before do
    sign_in admin_user, scope: :admin_user
  end

  describe 'POST /admin/ai_test/process_prompt' do
    it 'processes prompt requests successfully' do
      # Mock the PromptProcessingService
      allow_any_instance_of(PromptProcessingService).to receive(:process_and_query).and_return({
        response: double(content: 'Test AI response'),
        ai_log: double(
          settings: { 'model' => 'x-ai/grok-code-fast-1' },
          input_tokens: 100,
          output_tokens: 50,
          total_cost: 0.001,
          processing_time: 1.5,
          id: 123
        )
      })

      # Make a POST request to the endpoint
      post '/admin/ai_test/process_prompt', params: {
        prompt_id: prompt.id,
        model: 'x-ai/grok-code-fast-1',
        tags: { text: 'Sample text', topic: 'Testing' }
      }, headers: { 'X-Requested-With' => 'XMLHttpRequest' }

      expect(response).to have_http_status(:success)
      
      json_response = JSON.parse(response.body)
      expect(json_response['response']).to eq('Test AI response')
      expect(json_response['model']).to eq('x-ai/grok-code-fast-1')
      expect(json_response['input_tokens']).to eq(100)
      expect(json_response['output_tokens']).to eq(50)
      expect(json_response['ai_log_id']).to eq(123)
    end

    it 'handles errors gracefully' do
      # Mock an error
      allow_any_instance_of(PromptProcessingService).to receive(:process_and_query).and_raise(StandardError.new('Test error'))

      post '/admin/ai_test/process_prompt', params: {
        prompt_id: prompt.id,
        tags: { text: 'Sample text' }
      }, headers: { 'X-Requested-With' => 'XMLHttpRequest' }

      expect(response).to have_http_status(:unprocessable_entity)
      
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to eq('Test error')
    end

    it 'requires authentication' do
      sign_out admin_user

      post '/admin/ai_test/process_prompt', params: {
        prompt_id: prompt.id,
        tags: { text: 'Sample text' }
      }, headers: { 'X-Requested-With' => 'XMLHttpRequest' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'validates prompt_id parameter' do
      post '/admin/ai_test/process_prompt', params: {
        tags: { text: 'Sample text' }
      }, headers: { 'X-Requested-With' => 'XMLHttpRequest' }

      expect(response).to have_http_status(:unprocessable_entity)
      
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('find')
    end

    it 'handles missing prompt gracefully' do
      post '/admin/ai_test/process_prompt', params: {
        prompt_id: 99999,
        tags: { text: 'Sample text' }
      }, headers: { 'X-Requested-With' => 'XMLHttpRequest' }

      expect(response).to have_http_status(:unprocessable_entity)
      
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('find')
    end

    it 'processes prompts with custom model selection' do
      # Mock the PromptProcessingService
      allow_any_instance_of(PromptProcessingService).to receive(:process_and_query).and_return({
        response: double(content: 'Custom model response'),
        ai_log: double(
          settings: { 'model' => 'custom-model' },
          input_tokens: 150,
          output_tokens: 75,
          total_cost: 0.002,
          processing_time: 2.1,
          id: 456
        )
      })

      post '/admin/ai_test/process_prompt', params: {
        prompt_id: prompt.id,
        model: 'custom-model',
        tags: { text: 'Custom text', topic: 'Custom topic' }
      }, headers: { 'X-Requested-With' => 'XMLHttpRequest' }

      expect(response).to have_http_status(:success)
      
      json_response = JSON.parse(response.body)
      expect(json_response['response']).to eq('Custom model response')
      expect(json_response['model']).to eq('custom-model')
    end

    it 'sets proper session context' do
      # Mock the PromptProcessingService to capture the session
      service_instance = instance_double(PromptProcessingService)
      allow(PromptProcessingService).to receive(:new).and_return(service_instance)
      allow(service_instance).to receive(:process_and_query).and_return({
        response: double(content: 'Test response'),
        ai_log: double(
          settings: { 'model' => 'test-model' },
          input_tokens: 50,
          output_tokens: 25,
          total_cost: 0.001,
          processing_time: 1.0,
          id: 789
        )
      })

      # Verify Current.ailog_session is set during processing
      expect(Current).to receive(:ailog_session=).with("ADMIN_TEST").ordered
      expect(Current).to receive(:ailog_session=).with(nil).ordered

      post '/admin/ai_test/process_prompt', params: {
        prompt_id: prompt.id,
        tags: { text: 'Test text' }
      }, headers: { 'X-Requested-With' => 'XMLHttpRequest' }

      expect(response).to have_http_status(:success)
    end

    it 'returns properly structured metadata for grid layout' do
      # Mock the PromptProcessingService
      allow_any_instance_of(PromptProcessingService).to receive(:process_and_query).and_return({
        response: double(content: 'Test AI response'),
        ai_log: double(
          settings: { 'model' => 'x-ai/grok-code-fast-1' },
          input_tokens: 150,
          output_tokens: 75,
          total_cost: 0.002,
          processing_time: 2.1,
          id: 456
        )
      })

      post '/admin/ai_test/process_prompt', params: {
        prompt_id: prompt.id,
        model: 'x-ai/grok-code-fast-1',
        tags: { text: 'Test text', topic: 'Test topic' }
      }, headers: { 'X-Requested-With' => 'XMLHttpRequest' }

      expect(response).to have_http_status(:success)

      json_response = JSON.parse(response.body)

      # Verify all metadata fields are present for grid display
      expect(json_response['model']).to eq('x-ai/grok-code-fast-1')
      expect(json_response['input_tokens']).to eq(150)
      expect(json_response['output_tokens']).to eq(75)
      expect(json_response['cost']).to eq('0.002000') # Cost is formatted as string
      expect(json_response['processing_time']).to be_a(Float)
      expect(json_response['ai_log_id']).to eq(456)
    end
  end
end
