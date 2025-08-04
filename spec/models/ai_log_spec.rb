# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLog, type: :model do
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
        expect(subject).to be_valid
      end
    end

    context 'with negative token values' do
      it 'is invalid with negative input_tokens' do
        subject.input_tokens = -1
        expect(subject).not_to be_valid
        expect(subject.errors[:input_tokens]).to include('must be greater than or equal to 0')
      end

      it 'is invalid with negative output_tokens' do
        subject.output_tokens = -1
        expect(subject).not_to be_valid
        expect(subject.errors[:output_tokens]).to include('must be greater than or equal to 0')
      end
    end
  end

  describe 'scopes' do
    let!(:recent_log) { create(:ai_log, :recent) }
    let!(:old_log) { create(:ai_log, :old) }
    let!(:chat_log) { create(:ai_log, :with_chat) }
    let!(:anthropic_log) { create(:ai_log, :anthropic_model) }

    describe '.recent' do
      it 'orders by created_at desc' do
        recent_logs = AiLog.recent.limit(2)
        expect(recent_logs.first.created_at).to be >= recent_logs.last.created_at
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
        expect(AiLog.by_model('').count).to eq(AiLog.count)
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
    let(:ai_log) { create(:ai_log, model: 'google/gemini-2.0-flash-001') }

    describe '#model_display_name' do
      it 'returns humanized model name' do
        expect(ai_log.model_display_name).to eq('Google/gemini-2.0-flash-001')
      end

      it 'returns Unknown Model for nil model' do
        ai_log.model = nil
        expect(ai_log.model_display_name).to eq('Unknown Model')
      end
    end

    describe '#settings_summary' do
      it 'extracts key settings' do
        ai_log.settings = {
          'temperature' => 0.7,
          'max_tokens' => 1000,
          'top_p' => 0.9,
          'other_setting' => 'ignored'
        }
        
        summary = ai_log.settings_summary
        expect(summary[:temperature]).to eq(0.7)
        expect(summary[:max_tokens]).to eq(1000)
        expect(summary[:top_p]).to eq(0.9)
        expect(summary).not_to have_key(:other_setting)
      end

      it 'returns empty hash for blank settings' do
        ai_log.settings = nil
        expect(ai_log.settings_summary).to eq({})
      end
    end

    describe '#has_chat_session?' do
      it 'returns true when chat_id is present' do
        ai_log.chat_id = 'some-uuid'
        expect(ai_log.has_chat_session?).to be true
      end

      it 'returns false when chat_id is nil' do
        ai_log.chat_id = nil
        expect(ai_log.has_chat_session?).to be false
      end
    end

    describe '#response_length' do
      it 'returns response length' do
        ai_log.response = 'Hello world'
        expect(ai_log.response_length).to eq(11)
      end

      it 'returns 0 for nil response' do
        ai_log.response = nil
        expect(ai_log.response_length).to eq(0)
      end
    end

    describe '#query_length' do
      it 'returns query length' do
        ai_log.query = 'Test query'
        expect(ai_log.query_length).to eq(10)
      end

      it 'returns 0 for nil query' do
        ai_log.query = nil
        expect(ai_log.query_length).to eq(0)
      end
    end

    describe '#total_tokens' do
      it 'sums input and output tokens' do
        ai_log.input_tokens = 100
        ai_log.output_tokens = 200
        expect(ai_log.total_tokens).to eq(300)
      end

      it 'handles nil values' do
        ai_log.input_tokens = nil
        ai_log.output_tokens = 200
        expect(ai_log.total_tokens).to eq(200)
      end
    end

    describe '#has_token_data?' do
      it 'returns true when input_tokens present' do
        ai_log.input_tokens = 100
        ai_log.output_tokens = nil
        expect(ai_log.has_token_data?).to be true
      end

      it 'returns true when output_tokens present' do
        ai_log.input_tokens = nil
        ai_log.output_tokens = 200
        expect(ai_log.has_token_data?).to be true
      end

      it 'returns false when both are nil' do
        ai_log.input_tokens = nil
        ai_log.output_tokens = nil
        expect(ai_log.has_token_data?).to be false
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

    it 'creates log with error' do
      log = create(:ai_log, :with_error)
      expect(log.response).to be_nil
      expect(log.pending?).to be true
    end
  end
end
