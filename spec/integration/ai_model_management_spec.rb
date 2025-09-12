# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Model Management Integration', type: :integration do
  let(:admin_user) { create(:admin_user) }
  
  before do
    # Mock RubyLLM configuration
    allow(RubyLLM.config).to receive(:default_model).and_return('ruby-llm/default')
    
    # Mock RubyLLM models for dropdown
    allow(RubyLLM).to receive(:models).and_return([
      double(name: 'Test Model 1', id: 'test/model-1', provider: 'test', context_window: 4096),
      double(name: 'Test Model 2', id: 'test/model-2', provider: 'test', context_window: 8192)
    ])
  end

  describe 'Complete AI Model Management Flow' do
    it 'manages allowed models and uses them in prompt processing' do
      # Step 1: Create allowed models
      model1 = create(:allowed_model, 
        name: 'Test Model 1', 
        model: 'test/model-1', 
        provider: 'test',
        active: true,
        default: true
      )
      
      model2 = create(:allowed_model,
        name: 'Test Model 2',
        model: 'test/model-2', 
        provider: 'test',
        active: true,
        default: false
      )

      # Step 2: Create a prompt with a specific model
      prompt = create(:prompt,
        name: 'test_prompt',
        content: 'Process this: %{text}',
        allowed_model: model2,
        created_by: admin_user,
        updated_by: admin_user
      )

      # Step 3: Verify model resolution in prompt
      expect(prompt.effective_model).to eq('test/model-2')
      expect(prompt.model_display_name).to eq('Test Model 2 (test)')

      # Step 4: Test PromptProcessingService model resolution
      service = PromptProcessingService.new
      effective_model = service.send(:resolve_effective_model, prompt)
      expect(effective_model).to eq('test/model-2')

      # Step 5: Test fallback when prompt model becomes inactive
      model2.update!(active: false)
      prompt.reload
      
      effective_model = service.send(:resolve_effective_model, prompt)
      expect(effective_model).to eq('test/model-1') # Falls back to default

      # Step 6: Test LLM QueryService model validation
      query_service = Llm::QueryService.new(model: 'test/model-1')
      expect(query_service.model).to eq('test/model-1')

      # Step 7: Test fallback when model is not allowed
      query_service = Llm::QueryService.new(model: 'not-allowed/model')
      expect(query_service.model).to eq('test/model-1') # Falls back to default

      # Step 8: Test final fallback when no allowed models
      prompt.update!(allowed_model: nil)  # Remove reference first
      AllowedModel.destroy_all
      query_service = Llm::QueryService.new(model: 'any/model')
      expect(query_service.model).to eq('ruby-llm/default')
    end

    it 'ensures only one default model exists' do
      model1 = create(:allowed_model, default: true)
      model2 = create(:allowed_model, default: false)

      # Making model2 default should remove default from model1
      model2.make_default!

      expect(model1.reload.default).to be false
      expect(model2.reload.default).to be true
    end

    it 'provides correct model data for dropdowns' do
      available_models = AllowedModel.available_models_for_dropdown
      
      expect(available_models).to contain_exactly(
        { name: 'Test Model 1', id: 'test/model-1', provider: 'test', context_size: 4096 },
        { name: 'Test Model 2', id: 'test/model-2', provider: 'test', context_size: 8192 }
      )
    end

    it 'handles context size display correctly' do
      model = create(:allowed_model, context_size: 1_500_000)
      expect(model.context_size_display).to eq('1.5M')

      model.update!(context_size: 128_000)
      expect(model.context_size_display).to eq('128.0K')

      model.update!(context_size: 512)
      expect(model.context_size_display).to eq('512')

      model.update!(context_size: nil)
      expect(model.context_size_display).to eq('Unknown')
    end
  end

  describe 'Model Selection Priority' do
    let(:prompt) { create(:prompt, created_by: admin_user, updated_by: admin_user) }
    
    it 'follows correct priority order' do
      # Create models
      prompt_model = create(:allowed_model, model: 'prompt/model', active: true)
      default_model = create(:allowed_model, model: 'default/model', active: true, default: true)
      
      # 1. Uses prompt model when available and active
      prompt.update!(allowed_model: prompt_model)
      expect(prompt.effective_model).to eq('prompt/model')
      
      # 2. Falls back to default when prompt model is inactive
      prompt_model.update!(active: false)
      expect(prompt.effective_model).to eq('default/model')
      
      # 3. Falls back to RubyLLM default when no allowed models
      prompt.update!(allowed_model: nil)  # Remove reference first
      AllowedModel.destroy_all
      expect(prompt.effective_model).to eq('ruby-llm/default')
    end
  end

  describe 'Service Integration' do
    it 'integrates PromptProcessingService with model resolution' do
      # Create allowed model
      allowed_model = create(:allowed_model, model: 'integration/model', active: true, default: true)
      
      # Create prompt
      prompt = create(:prompt,
        name: 'integration_test',
        content: 'Test: %{query}',
        created_by: admin_user,
        updated_by: admin_user
      )

      # Mock LLM service
      mock_llm_service = double('Llm::QueryService')
      mock_response = double('Response', content: 'Mock response')
      mock_ai_log = double('AiLog', id: 1)

      allow(Llm::QueryService).to receive(:new).with(
        temperature: 0.7,
        model: 'integration/model'
      ).and_return(mock_llm_service)
      
      allow(mock_llm_service).to receive(:ask).and_return(mock_response)
      allow(mock_llm_service).to receive(:ai_log).and_return(mock_ai_log)

      # Test service
      service = PromptProcessingService.new
      result = service.process_and_query(
        prompt_key: 'integration_test',
        query: 'test query'
      )

      expect(result[:response]).to eq(mock_response)
      expect(result[:prompt]).to eq(prompt)
    end
  end
end
