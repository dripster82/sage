# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Llm::QueryService, type: :service do
  let(:service) { Llm::QueryService.new }

  before do
    Current.ailog_session = nil # Ensure clean state for each test
  end

  after do
    Current.ailog_session = nil # Clean up after each test
  end

  it 'responds to ask method' do
    expect(service).to respond_to(:ask)
  end

  describe 'initialization' do
    it 'sets default temperature' do
      expect(service.temperature).to eq(0.7)
    end

    it 'sets default model from RubyLLM config' do
      expect(service.model).to eq(RubyLLM.config.default_model)
    end

    it 'accepts custom temperature' do
      custom_service = Llm::QueryService.new(temperature: 0.5)
      expect(custom_service.temperature).to eq(0.5)
    end

    it 'accepts custom model' do
      custom_service = Llm::QueryService.new(model: 'custom-model')
      expect(custom_service.model).to eq('custom-model')
    end
  end

  describe '#ask' do
    let(:query) { 'What is the capital of France?' }
    let(:mock_chat) { double('RubyLLM Chat') }
    let(:mock_response) { double('Response', content: 'Paris', input_tokens: 10, output_tokens: 5) }
    let(:mock_model) { double('Model') }
    let(:mock_pricing) { double('Pricing') }
    let(:mock_text_tokens) { double('TextTokens') }
    let(:mock_standard) { double('Standard') }

    before do
      # Set up the full pricing mock structure
      allow(mock_standard).to receive(:input_per_million).and_return(1.0)
      allow(mock_standard).to receive(:output_per_million).and_return(2.0)
      allow(mock_text_tokens).to receive(:standard).and_return(mock_standard)
      allow(mock_pricing).to receive(:text_tokens).and_return(mock_text_tokens)
      allow(mock_model).to receive(:pricing).and_return(mock_pricing)
      allow(mock_model).to receive(:id).and_return('test-model')
      allow(mock_model).to receive(:provider).and_return('test-provider')

      allow(mock_chat).to receive(:model).and_return(mock_model)
      allow(mock_chat).to receive(:with_temperature).and_return(mock_chat)
      allow(mock_chat).to receive(:ask).and_return(mock_response)
      allow(RubyLLM).to receive(:chat).and_return(mock_chat)

      # Mock AiLog creation
      ai_log = double('AiLog', id: 1)
      allow(ai_log).to receive(:settings).and_return({})
      allow(ai_log).to receive(:update!)
      allow(AiLog).to receive(:create!).and_return(ai_log)
    end

    it 'creates RubyLLM chat with correct model' do
      expect(RubyLLM).to receive(:chat).with(model: service.model)
      service.ask(query)
    end

    it 'sets temperature on chat' do
      expect(mock_chat).to receive(:with_temperature).with(0.7)
      service.ask(query)
    end

    it 'sends query to chat' do
      expect(mock_chat).to receive(:ask).with(query)
      service.ask(query)
    end

    it 'returns response from chat' do
      result = service.ask(query)
      expect(result).to eq(mock_response)
    end

    it 'creates AI log entry' do
      expect(AiLog).to receive(:create!).with(
        model: service.model,
        query: query,
        chat_id: nil,
        session_uuid: nil,
        settings: {
          temperature: 0.7,
          model: service.model
        }
      )
      service.ask(query)
    end

    it 'creates AI log with chat_id when provided' do
      chat_id = 'test-chat-id'
      expect(AiLog).to receive(:create!).with(
        hash_including(chat_id: chat_id)
      )
      service.ask(query, chat_id: chat_id)
    end

    it 'updates log with response data' do
      ai_log = double('AiLog')
      allow(ai_log).to receive(:settings).and_return({})
      allow(AiLog).to receive(:create!).and_return(ai_log)

      # Mock the chat model for pricing
      mock_model = double('Model')
      mock_pricing = double('Pricing')
      mock_text_tokens = double('TextTokens')
      mock_standard = double('Standard')

      allow(mock_chat).to receive(:model).and_return(mock_model)
      allow(mock_model).to receive(:pricing).and_return(mock_pricing)
      allow(mock_model).to receive(:id).and_return('test-model')
      allow(mock_model).to receive(:provider).and_return('test-provider')
      allow(mock_pricing).to receive(:text_tokens).and_return(mock_text_tokens)
      allow(mock_text_tokens).to receive(:standard).and_return(mock_standard)
      allow(mock_standard).to receive(:input_per_million).and_return(1.0)
      allow(mock_standard).to receive(:output_per_million).and_return(2.0)

      expect(ai_log).to receive(:update!).with(
        hash_including(
          response: 'Paris',
          input_tokens: 10,
          output_tokens: 5,
          total_cost: kind_of(Numeric)
        )
      )

      service.ask(query)
    end

    it 'uses Current.ailog_session when available' do
      session_uuid = SecureRandom.uuid
      Current.ailog_session = session_uuid
      
      expect(AiLog).to receive(:create!).with(
        hash_including(session_uuid: session_uuid)
      )
      
      service.ask(query)
      
      Current.ailog_session = nil
    end
  end

  describe '#json_from_query' do
    let(:query) { 'Return JSON data' }
    let(:json_content) { '{"key": "value", "number": 42}' }
    let(:mock_response) { double('Response', content: json_content) }

    before do
      allow(service).to receive(:ask).and_return(mock_response)
      allow(service).to receive(:strip_formatting).and_return(json_content)
      allow(JSON).to receive(:repair).and_return(json_content)
    end

    it 'calls ask method' do
      expect(service).to receive(:ask).with(query, chat_id: nil)
      service.json_from_query(query)
    end

    it 'parses JSON response' do
      result = service.json_from_query(query)
      expect(result).to eq({ 'key' => 'value', 'number' => 42 })
    end

    it 'passes chat_id to ask method' do
      chat_id = 'test-chat'
      expect(service).to receive(:ask).with(query, chat_id: chat_id)
      service.json_from_query(query, chat_id: chat_id)
    end

    it 'handles JSON with formatting' do
      formatted_json = "```json\n#{json_content}\n```"
      formatted_response = double('Response', content: formatted_json)
      allow(service).to receive(:ask).and_return(formatted_response)
      allow(service).to receive(:strip_formatting).with(formatted_json).and_return(json_content)

      result = service.json_from_query(query)
      expect(result).to eq({ 'key' => 'value', 'number' => 42 })
    end

    it 'repairs malformed JSON' do
      malformed_json = '{"key": "value", "number": 42'  # Missing closing brace
      malformed_response = double('Response', content: malformed_json)
      allow(service).to receive(:ask).and_return(malformed_response)
      allow(service).to receive(:strip_formatting).with(malformed_json).and_return(malformed_json)

      # Mock JSON.repair to fix the malformed JSON
      allow(JSON).to receive(:repair).with(malformed_json).and_return('{"key": "value", "number": 42}')

      result = service.json_from_query(query)
      expect(result).to eq({ 'key' => 'value', 'number' => 42 })
    end
  end

  describe 'error handling' do
    let(:query) { 'Test query' }
    let(:mock_chat) { double('RubyLLM Chat') }

    before do
      allow(RubyLLM).to receive(:chat).and_return(mock_chat)
      allow(mock_chat).to receive(:with_temperature).and_return(mock_chat)
    end

    it 'handles LLM API errors' do
      ai_log = double('AiLog')
      allow(ai_log).to receive(:settings).and_return({})
      allow(ai_log).to receive(:update!)
      allow(AiLog).to receive(:create!).and_return(ai_log)
      allow(mock_chat).to receive(:ask).and_raise(StandardError, 'API Error')

      expect(ai_log).to receive(:update!).with(
        hash_including(response: 'ERROR: API Error')
      )

      expect {
        service.ask(query)
      }.to raise_error(StandardError, 'API Error')
    end

    it 'handles JSON parsing errors in json_from_query' do
      invalid_json_response = double('Response', content: 'Not JSON')
      allow(service).to receive(:ask).and_return(invalid_json_response)
      allow(JSON).to receive(:repair).and_return('Still not JSON')

      expect {
        service.json_from_query(query)
      }.to raise_error(JSON::ParserError)
    end

    it 'handles network timeouts' do
      ai_log = double('AiLog')
      allow(ai_log).to receive(:settings).and_return({})
      allow(ai_log).to receive(:update!)
      allow(AiLog).to receive(:create!).and_return(ai_log)
      allow(mock_chat).to receive(:ask).and_raise(Timeout::Error)

      expect(ai_log).to receive(:update!).with(
        hash_including(response: 'ERROR: Timeout::Error')
      )

      expect {
        service.ask(query)
      }.to raise_error(Timeout::Error)
    end
  end

  describe 'JSON formatting' do
    it 'handles formatted JSON responses' do
      formatted_json = "```json\n{\"key\": \"value\"}\n```"
      formatted_response = double('Response', content: formatted_json)

      allow(service).to receive(:ask).and_return(formatted_response)

      # Mock the JSON repair to return valid JSON
      allow(JSON).to receive(:repair).and_return('{"key": "value"}')

      result = service.json_from_query('test query')
      expect(result).to be_a(Hash)
      expect(result['key']).to eq('value')
    end

    it 'handles plain JSON responses' do
      plain_json = '{"key": "value"}'
      plain_response = double('Response', content: plain_json)

      allow(service).to receive(:ask).and_return(plain_response)

      # Mock the JSON repair to return valid JSON
      allow(JSON).to receive(:repair).and_return('{"key": "value"}')

      result = service.json_from_query('test query')
      expect(result).to be_a(Hash)
      expect(result['key']).to eq('value')
    end
  end

  describe 'private methods' do
    describe '#create_log_entry' do
        before do
          Current.ailog_session = nil # Ensure clean state
        end

        after do
          Current.ailog_session = nil # Clean up
        end

        it 'creates AiLog with correct attributes' do
          query = 'Test query'
          chat_id = 'test-chat'

          expect(AiLog).to receive(:create!).with(
            model: service.model,
            query: query,
            chat_id: chat_id,
            session_uuid: nil,
            settings: {
              temperature: service.temperature,
              model: service.model
            }
          )

          service.send(:create_log_entry, query, chat_id)
        end
      end

      describe '#update_log_with_response' do
        let(:ai_log) { double('AiLog') }
        let(:response) { double('Response', content: 'Test', input_tokens: 10, output_tokens: 5) }
        let(:mock_chat) { double('Chat') }
        let(:mock_model) { double('Model') }

        before do
          # Mock the pricing structure
          mock_pricing = double('Pricing')
          mock_text_tokens = double('TextTokens')
          mock_standard = double('Standard')

          allow(mock_model).to receive(:pricing).and_return(mock_pricing)
          allow(mock_model).to receive(:id).and_return('test-model')
          allow(mock_model).to receive(:provider).and_return('test-provider')
          allow(mock_pricing).to receive(:text_tokens).and_return(mock_text_tokens)
          allow(mock_text_tokens).to receive(:standard).and_return(mock_standard)
          allow(mock_standard).to receive(:input_per_million).and_return(1.0)
          allow(mock_standard).to receive(:output_per_million).and_return(2.0)

          allow(mock_chat).to receive(:model).and_return(mock_model)
          allow(ai_log).to receive(:settings).and_return({})

          service.instance_variable_set(:@chat, mock_chat)
          service.instance_variable_set(:@ai_log, ai_log)
        end

        it 'updates log with response data and pricing' do
          expect(ai_log).to receive(:update!).with(
            hash_including(
              response: 'Test',
              input_tokens: 10,
              output_tokens: 5,
              total_cost: kind_of(Numeric)
            )
          )

          service.send(:update_log_with_response, response)
        end
      end

      describe '#update_log_with_error' do
        let(:ai_log) { double('AiLog') }
        let(:error) { StandardError.new('Test error') }

        before do
          allow(ai_log).to receive(:settings).and_return({})
          service.instance_variable_set(:@ai_log, ai_log)
        end

        it 'updates log with error information' do
          expect(ai_log).to receive(:update!).with(
            hash_including(
              response: 'ERROR: Test error'
            )
          )

          service.send(:update_log_with_error, error)
        end
      end
    end
  end

  describe 'integration with RubyLLM' do
    let(:service) { Llm::QueryService.new }

    it 'uses configured default model' do
      expect(service.model).to eq(RubyLLM.config.default_model)
    end

    it 'creates chat with RubyLLM' do
      expect(RubyLLM).to receive(:chat).with(model: service.model)

        # Set up complete mock structure
        mock_chat = double('Chat')
        mock_model = double('Model')
        mock_pricing = double('Pricing')
        mock_text_tokens = double('TextTokens')
        mock_standard = double('Standard')

        allow(mock_standard).to receive(:input_per_million).and_return(1.0)
        allow(mock_standard).to receive(:output_per_million).and_return(2.0)
        allow(mock_text_tokens).to receive(:standard).and_return(mock_standard)
        allow(mock_pricing).to receive(:text_tokens).and_return(mock_text_tokens)
        allow(mock_model).to receive(:pricing).and_return(mock_pricing)
        allow(mock_model).to receive(:id).and_return('test-model')
        allow(mock_model).to receive(:provider).and_return('test-provider')

        allow(mock_chat).to receive(:model).and_return(mock_model)
        allow(mock_chat).to receive(:with_temperature).and_return(mock_chat)
        allow(mock_chat).to receive(:ask).and_return(double(content: 'response', input_tokens: 10, output_tokens: 5))
        allow(RubyLLM).to receive(:chat).and_return(mock_chat)

        ai_log = double('AiLog')
        allow(ai_log).to receive(:settings).and_return({})
        allow(ai_log).to receive(:update!)
        allow(AiLog).to receive(:create!).and_return(ai_log)

        service.ask('test')
      end

  describe 'performance' do
    before do
      mock_llm_response
    end

    it 'handles multiple queries efficiently' do
      expect {
        Timeout.timeout(5) do
          10.times { service.ask('Quick test query') }
        end
      }.not_to raise_error
    end
  end
end
