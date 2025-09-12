# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PromptProcessingService, type: :service do
  let(:service) { PromptProcessingService.new }
  let(:prompt) { create(:prompt, name: 'test_prompt', content: 'Hello %{name}, your age is %{age}. Query: %{query}') }
  let(:mock_llm_service) { double('Llm::QueryService') }
  let(:mock_response) { double('Response', content: 'Mock LLM response') }
  let(:mock_ai_log) { double('AiLog', id: 1) }

  before do
    # Mock the prompt tags to include query
    allow(prompt).to receive(:tags_hash).and_return({ name: nil, age: nil, query: nil })

    # Mock the LLM service
    allow(Llm::QueryService).to receive(:new).and_return(mock_llm_service)
    allow(mock_llm_service).to receive(:ask).and_return(mock_response)
    allow(mock_llm_service).to receive(:json_from_query).and_return({ result: 'parsed json' })
    allow(mock_llm_service).to receive(:ai_log).and_return(mock_ai_log)
  end

  describe '#process_and_query' do
    context 'when prompt exists' do
      before do
        allow(Prompt).to receive(:find_by).with(name: 'test_prompt').and_return(prompt)
      end

      it 'processes prompt and queries LLM with provided parameters' do
        result = service.process_and_query(
          prompt_key: 'test_prompt',
          query: 'What is my status?',
          parameters: { name: 'John', age: '25' }
        )

        expect(result[:processed_prompt]).to eq('Hello John, your age is 25. Query: What is my status?')
        expect(result[:original_query]).to eq('What is my status?')
        expect(result[:prompt]).to eq(prompt)
        expect(result[:response]).to eq(mock_response)
        expect(result[:ai_log]).to eq(mock_ai_log)
      end

      it 'passes temperature and model to LLM service' do
        service_with_options = PromptProcessingService.new(temperature: 0.5, model: 'test-model')

        expect(Llm::QueryService).to receive(:new).with(temperature: 0.5, model: 'test-model')

        service_with_options.process_and_query(
          prompt_key: 'test_prompt',
          query: 'What is my status?',
          parameters: { name: 'John' }
        )
      end

      it 'passes chat_id to LLM service' do
        expect(mock_llm_service).to receive(:ask).with(anything, chat_id: 'test-chat-id')

        service.process_and_query(
          prompt_key: 'test_prompt',
          query: 'What is my status?',
          parameters: { name: 'John' },
          chat_id: 'test-chat-id'
        )
      end
    end

    context 'when prompt does not exist' do
      before do
        allow(Prompt).to receive(:find_by).with(name: 'nonexistent').and_return(nil)
      end

      it 'raises an error' do
        expect {
          service.process_and_query(
            prompt_key: 'nonexistent',
            query: 'What is my status?',
            parameters: {}
          )
        }.to raise_error(PromptProcessingService::PromptNotFoundError, 'Prompt not found: nonexistent')
      end
    end
  end

  describe '#process_and_query_json' do
    before do
      allow(Prompt).to receive(:find_by).with(name: 'test_prompt').and_return(prompt)
    end

    it 'processes prompt and queries LLM for JSON response' do
      result = service.process_and_query_json(
        prompt_key: 'test_prompt',
        query: 'What is my status?',
        parameters: { name: 'John', age: '25' }
      )

      expect(result[:processed_prompt]).to eq('Hello John, your age is 25. Query: What is my status?')
      expect(result[:response]).to eq({ result: 'parsed json' })
      expect(mock_llm_service).to have_received(:json_from_query)
    end
  end

  describe 'parameter validation' do
    it 'raises error for missing query' do
      expect {
        service.process_and_query(
          prompt_key: 'test_prompt',
          parameters: {}
        )
      }.to raise_error(PromptProcessingService::MissingParameterError, 'Query is required')
    end

    it 'raises error for missing prompt_key' do
      expect {
        service.process_and_query(
          query: 'What is my status?',
          parameters: {}
        )
      }.to raise_error(PromptProcessingService::MissingParameterError, 'Prompt key is required')
    end
  end

  describe '#resolve_effective_model' do
    let(:prompt) { create(:prompt) }

    before do
      allow(RubyLLM.config).to receive(:default_model).and_return('ruby-llm/default')
    end

    context 'when service has explicit model' do
      let(:service) { PromptProcessingService.new(model: 'explicit/model') }

      it 'uses explicit model if it is allowed' do
        create(:allowed_model, model: 'explicit/model', active: true)
        expect(service.send(:resolve_effective_model, prompt)).to eq('explicit/model')
      end

      it 'falls back when explicit model is not allowed' do
        create(:allowed_model, model: 'fallback/model', active: true, default: true)
        expect(service.send(:resolve_effective_model, prompt)).to eq('fallback/model')
      end
    end

    context 'when prompt has assigned model' do
      it 'uses prompt model if active' do
        allowed_model = create(:allowed_model, model: 'prompt/model', active: true)
        prompt.allowed_model = allowed_model
        expect(service.send(:resolve_effective_model, prompt)).to eq('prompt/model')
      end

      it 'falls back when prompt model is inactive' do
        inactive_model = create(:allowed_model, model: 'prompt/model', active: false)
        default_model = create(:allowed_model, model: 'default/model', active: true, default: true)
        prompt.allowed_model = inactive_model

        expect(service.send(:resolve_effective_model, prompt)).to eq('default/model')
      end
    end

    context 'when falling back to default' do
      it 'uses default allowed model' do
        create(:allowed_model, model: 'default/model', active: true, default: true)
        expect(service.send(:resolve_effective_model, prompt)).to eq('default/model')
      end

      it 'uses RubyLLM default as final fallback' do
        expect(service.send(:resolve_effective_model, prompt)).to eq('ruby-llm/default')
      end
    end
  end
end
