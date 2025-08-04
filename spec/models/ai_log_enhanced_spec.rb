# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLog, type: :model do
  # Test data
  let(:valid_model) { 'google/gemini-2.0-flash-001' }
  let(:valid_query) { 'What is the capital of France?' }
  let(:valid_response) { 'The capital of France is Paris.' }
  let(:valid_settings) { { 'temperature' => 0.7, 'max_tokens' => 1000 } }
  let(:valid_input_tokens) { 100 }
  let(:valid_output_tokens) { 50 }
  let(:valid_session_uuid) { SecureRandom.uuid }
  let(:valid_chat_id) { 12345 }
  
  let(:invalid_input_tokens) { -10 }
  let(:invalid_output_tokens) { -5 }
  
  let(:expected_model_display) { 'Google/gemini-2.0-flash-001' }
  let(:expected_settings_keys) { %w[temperature max_tokens top_p] }
  let(:expected_total_tokens) { valid_input_tokens + valid_output_tokens }
  
  subject { build(:ai_log) }

  it_behaves_like 'an ActiveRecord model'

  describe 'validations' do
    it { should validate_presence_of(:model) }
    it { should validate_presence_of(:query) }
    it { should validate_presence_of(:settings) }
    it { should validate_numericality_of(:input_tokens).is_greater_than_or_equal_to(0).allow_nil }
    it { should validate_numericality_of(:output_tokens).is_greater_than_or_equal_to(0).allow_nil }

    context 'with valid attributes' do
      it 'is valid' do
        log = build(:ai_log, model: valid_model, query: valid_query, settings: valid_settings)
        expect(log).to be_valid
      end
    end

    context 'with invalid token values' do
      it 'rejects negative input tokens' do
        log = build(:ai_log, input_tokens: invalid_input_tokens)
        expect(log).not_to be_valid
        expect(log.errors[:input_tokens]).to include('must be greater than or equal to 0')
      end

      it 'rejects negative output tokens' do
        log = build(:ai_log, output_tokens: invalid_output_tokens)
        expect(log).not_to be_valid
        expect(log.errors[:output_tokens]).to include('must be greater than or equal to 0')
      end
    end
  end

  describe 'scopes' do
    let!(:recent_log) { create(:ai_log, created_at: 1.hour.ago) }
    let!(:old_log) { create(:ai_log, created_at: 1.month.ago) }
    let!(:chat_log) { create(:ai_log, chat_id: valid_chat_id) }
    let!(:anthropic_log) { create(:ai_log, model: 'anthropic/claude-3.5-haiku') }

    describe '.recent' do
      it 'orders by created_at desc' do
        logs = AiLog.recent.limit(2)
        expect(logs.first.created_at).to be >= logs.last.created_at
      end
    end

    describe '.by_model' do
      it 'filters by model name' do
        results = AiLog.by_model('anthropic/claude-3.5-haiku')
        expect(results).to include(anthropic_log)
        expect(results).not_to include(recent_log)
      end

      it 'returns all records when model is blank' do
        expect(AiLog.by_model(nil).count).to eq(AiLog.count)
      end
    end

    describe '.with_chat' do
      it 'returns logs with chat_id' do
        results = AiLog.with_chat
        expect(results).to include(chat_log)
        expect(results).not_to include(recent_log)
      end
    end

    describe '.without_chat' do
      it 'returns logs without chat_id' do
        results = AiLog.without_chat
        expect(results).to include(recent_log)
        expect(results).not_to include(chat_log)
      end
    end
  end

  describe 'instance methods' do
    let(:ai_log) { create(:ai_log, model: valid_model, input_tokens: valid_input_tokens, output_tokens: valid_output_tokens) }

    describe '#model_display_name' do
      it 'returns formatted model name' do
        expect(ai_log.model_display_name).to eq(expected_model_display)
      end

      it 'handles nil model gracefully' do
        ai_log.model = nil
        expect(ai_log.model_display_name).to eq('Unknown Model')
      end
    end

    describe '#settings_summary' do
      let(:full_settings) do
        {
          'temperature' => 0.7,
          'max_tokens' => 1000,
          'top_p' => 0.9,
          'ignored_setting' => 'value'
        }
      end
      let(:expected_summary) { { temperature: 0.7, max_tokens: 1000, top_p: 0.9 } }

      it 'extracts key settings only' do
        ai_log.settings = full_settings
        expect(ai_log.settings_summary).to eq(expected_summary)
      end

      it 'handles blank settings' do
        ai_log.settings = nil
        expect(ai_log.settings_summary).to eq({})
      end
    end

    describe '#has_chat_session?' do
      it 'returns true when chat_id present' do
        ai_log.chat_id = valid_chat_id
        expect(ai_log.has_chat_session?).to be true
      end

      it 'returns false when chat_id nil' do
        ai_log.chat_id = nil
        expect(ai_log.has_chat_session?).to be false
      end
    end

    describe '#total_tokens' do
      it 'sums input and output tokens' do
        expect(ai_log.total_tokens).to eq(expected_total_tokens)
      end

      it 'handles nil values gracefully' do
        ai_log.input_tokens = nil
        ai_log.output_tokens = valid_output_tokens
        expect(ai_log.total_tokens).to eq(valid_output_tokens)
      end
    end

    describe '#has_token_data?' do
      it 'returns true when input_tokens present' do
        ai_log.input_tokens = valid_input_tokens
        ai_log.output_tokens = nil
        expect(ai_log.has_token_data?).to be true
      end

      it 'returns true when output_tokens present' do
        ai_log.input_tokens = nil
        ai_log.output_tokens = valid_output_tokens
        expect(ai_log.has_token_data?).to be true
      end

      it 'returns false when both nil' do
        ai_log.input_tokens = nil
        ai_log.output_tokens = nil
        expect(ai_log.has_token_data?).to be false
      end
    end

    describe '#response_length' do
      it 'returns response length' do
        ai_log.response = valid_response
        expect(ai_log.response_length).to eq(valid_response.length)
      end

      it 'returns 0 for nil response' do
        ai_log.response = nil
        expect(ai_log.response_length).to eq(0)
      end
    end
  end

  describe 'factory traits' do
    it 'creates log with chat' do
      log = create(:ai_log, :with_chat)
      expect(log.chat_id).to be_present
    end

    it 'creates log with high tokens' do
      log = create(:ai_log, :with_high_tokens)
      expect(log.input_tokens).to be >= 1000
      expect(log.output_tokens).to be >= 1500
    end

    it 'creates log with error state' do
      log = create(:ai_log, :with_error)
      expect(log.response).to be_nil
    end
  end

  describe 'data integrity' do
    it 'maintains consistent token calculations' do
      log = create(:ai_log, input_tokens: 100, output_tokens: 200)
      expect(log.total_tokens).to eq(300)
      expect(log.has_token_data?).to be true
    end

    it 'handles edge cases gracefully' do
      log = create(:ai_log, input_tokens: 0, output_tokens: 0)
      expect(log.total_tokens).to eq(0)
      expect(log.has_token_data?).to be true
    end
  end
end
