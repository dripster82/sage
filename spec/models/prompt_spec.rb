# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Prompt, type: :model do
  subject { build(:prompt) }

  it_behaves_like 'an ActiveRecord model'

  describe 'associations' do
    it { should belong_to(:created_by).class_name('AdminUser') }
    it { should belong_to(:updated_by).class_name('AdminUser') }
    it { should belong_to(:allowed_model).optional }
    it { should have_many(:prompt_versions).dependent(:destroy) }
    it { should have_one(:current_version_record).class_name('PromptVersion') }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_presence_of(:content) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[active inactive draft]) }
    it { should validate_presence_of(:current_version) }
    it { should validate_numericality_of(:current_version).is_greater_than(0) }

    context 'with valid attributes' do
      it 'is valid' do
        expect(subject).to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:active_prompt) { create(:prompt, status: 'active') }
    let!(:inactive_prompt) { create(:prompt, :inactive) }
    let!(:draft_prompt) { create(:prompt, :draft) }
    let!(:kg_prompt) { create(:prompt, category: 'knowledge_graph') }

    describe '.active' do
      it 'returns active prompts' do
        expect(Prompt.active).to include(active_prompt)
        expect(Prompt.active).not_to include(inactive_prompt, draft_prompt)
      end
    end

    describe '.inactive' do
      it 'returns inactive prompts' do
        expect(Prompt.inactive).to include(inactive_prompt)
        expect(Prompt.inactive).not_to include(active_prompt, draft_prompt)
      end
    end

    describe '.draft' do
      it 'returns draft prompts' do
        expect(Prompt.draft).to include(draft_prompt)
        expect(Prompt.draft).not_to include(active_prompt, inactive_prompt)
      end
    end

    describe '.by_category' do
      it 'filters by category' do
        results = Prompt.by_category('knowledge_graph')
        expect(results).to include(kg_prompt)
      end

      it 'returns all when category is blank' do
        expect(Prompt.by_category(nil).count).to eq(Prompt.count)
      end
    end
  end

  describe 'callbacks' do
    describe 'after_create' do
      it 'creates initial version' do
        prompt = create(:prompt)
        expect(prompt.prompt_versions.count).to eq(1)
        expect(prompt.prompt_versions.first.version_number).to eq(1)
        expect(prompt.prompt_versions.first.is_current).to be true
      end
    end

    describe 'before_save' do
      it 'extracts tags from content' do
        prompt = build(:prompt, content: 'Process %{text} with %{schema}')
        prompt.save!
        expect(JSON.parse(prompt.tags)).to match_array(['text', 'schema'])
      end
    end

    describe 'before_update' do
      it 'creates new version when content changes' do
        prompt = create(:prompt)
        initial_version_count = prompt.prompt_versions.count
        
        prompt.update!(content: 'New content with %{new_tag}')
        
        expect(prompt.prompt_versions.count).to eq(initial_version_count + 1)
        expect(prompt.current_version).to eq(2)
      end
    end
  end

  describe 'instance methods' do
    let(:prompt) { create(:prompt) }

    describe '#create_version!' do
      it 'creates new version and updates current_version' do
        admin_user = create(:admin_user)
        initial_version = prompt.current_version
        
        new_version = prompt.create_version!(
          change_summary: 'Test update',
          created_by: admin_user
        )
        
        expect(new_version.version_number).to eq(initial_version + 1)
        expect(new_version.is_current).to be true
        expect(prompt.reload.current_version).to eq(initial_version + 1)
      end

      it 'marks previous version as not current' do
        admin_user = create(:admin_user)
        old_version = prompt.current_version_record
        
        prompt.create_version!(created_by: admin_user)
        
        expect(old_version.reload.is_current).to be false
      end
    end

    describe '#revert_to_version!' do
      it 'reverts to specified version' do
        admin_user = create(:admin_user)
        original_content = prompt.content
        
        # Create a new version
        prompt.update!(content: 'Updated content')
        
        # Revert to version 1
        prompt.revert_to_version!(1, reverted_by: admin_user)
        
        expect(prompt.content).to eq(original_content)
        expect(prompt.current_version).to eq(3) # New version created for revert
      end
    end

    describe '#version_history' do
      it 'returns versions ordered by version number' do
        admin_user = create(:admin_user)
        prompt.create_version!(created_by: admin_user)
        prompt.create_version!(created_by: admin_user)
        
        history = prompt.version_history
        expect(history.map(&:version_number)).to eq([1, 2, 3])
      end
    end

    describe '#latest_versions' do
      it 'returns latest versions with limit' do
        admin_user = create(:admin_user)
        3.times { prompt.create_version!(created_by: admin_user) }
        
        latest = prompt.latest_versions(2)
        expect(latest.count).to eq(2)
        expect(latest.first.version_number).to be > latest.last.version_number
      end
    end

    describe '#version_at' do
      it 'returns version at specified number' do
        version = prompt.version_at(1)
        expect(version.version_number).to eq(1)
      end
    end

    describe '#content_changed_since_last_version?' do
      it 'returns true when content changed' do
        prompt.content = 'New content'
        expect(prompt.content_changed_since_last_version?).to be true
      end

      it 'returns false when content unchanged' do
        expect(prompt.content_changed_since_last_version?).to be false
      end
    end

    describe '#tags_list' do
      it 'returns parsed tags array' do
        prompt.tags = ['text', 'schema'].to_json
        expect(prompt.tags_list).to match_array(['text', 'schema'])
      end
    end

    describe '#tags_hash' do
      it 'returns hash with tag keys and nil values' do
        prompt.tags = ['text', 'schema'].to_json
        expected = { text: nil, schema: nil }
        expect(prompt.tags_hash).to eq(expected)
      end
    end

    describe '#effective_model' do
      before do
        allow(RubyLLM.config).to receive(:default_model).and_return('ruby-llm/default')
      end

      it 'returns allowed model when active' do
        allowed_model = create(:allowed_model, model: 'test/model', active: true)
        prompt.allowed_model = allowed_model
        expect(prompt.effective_model).to eq('test/model')
      end

      it 'falls back to default allowed model when prompt model is inactive' do
        inactive_model = create(:allowed_model, model: 'test/inactive', active: false)
        default_model = create(:allowed_model, model: 'test/default', active: true, default: true)
        prompt.allowed_model = inactive_model

        expect(prompt.effective_model).to eq('test/default')
      end

      it 'falls back to RubyLLM default when no allowed models' do
        expect(prompt.effective_model).to eq('ruby-llm/default')
      end
    end

    describe '#model_display_name' do
      it 'returns allowed model display name when present' do
        allowed_model = create(:allowed_model, name: 'Test Model', provider: 'test')
        prompt.allowed_model = allowed_model
        expect(prompt.model_display_name).to eq('Test Model (test)')
      end

      it 'returns default model name when no allowed model' do
        allow(RubyLLM.config).to receive(:default_model).and_return('ruby-llm/default')
        expect(prompt.model_display_name).to eq('Default (ruby-llm/default)')
      end
    end
  end

  describe 'factory traits' do
    it 'creates inactive prompt' do
      prompt = create(:prompt, :inactive)
      expect(prompt.status).to eq('inactive')
    end

    it 'creates draft prompt' do
      prompt = create(:prompt, :draft)
      expect(prompt.status).to eq('draft')
    end

    it 'creates prompt with multiple tags' do
      prompt = create(:prompt, :with_multiple_tags)
      expect(JSON.parse(prompt.tags)).to include('text', 'schema', 'summary')
    end

    it 'creates text summarization prompt' do
      prompt = create(:prompt, :text_summarization)
      expect(prompt.name).to eq('text_summarization')
      expect(prompt.category).to eq('summarization')
    end

    it 'creates kg extraction prompt' do
      prompt = create(:prompt, :kg_extraction)
      expect(prompt.name).to eq('kg_extraction_1st_pass')
      expect(prompt.category).to eq('knowledge_graph')
    end
  end
end
