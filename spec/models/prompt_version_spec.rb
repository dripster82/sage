# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PromptVersion, type: :model do
  subject { build(:prompt_version) }

  it_behaves_like 'an ActiveRecord model'

  describe 'associations' do
    it { should belong_to(:prompt) }
    it { should belong_to(:created_by).class_name('AdminUser') }
  end

  describe 'validations' do
    it { should validate_presence_of(:version_number) }
    it { should validate_uniqueness_of(:version_number).scoped_to(:prompt_id) }
    it { should validate_numericality_of(:version_number).is_greater_than(0) }
    it { should validate_presence_of(:content) }
    it { should validate_presence_of(:name) }

    context 'with valid attributes' do
      it 'is valid' do
        expect(subject).to be_valid
      end
    end
  end

  describe 'scopes' do
    let(:prompt) { create(:prompt) }
    let!(:current_version) { prompt.current_version_record }
    let!(:historical_version) { create(:prompt_version, :historical, prompt: prompt, version_number: 2) }

    describe '.current' do
      it 'returns current versions' do
        expect(PromptVersion.current).to include(current_version)
        expect(PromptVersion.current).not_to include(historical_version)
      end
    end

    describe '.historical' do
      it 'returns historical versions' do
        expect(PromptVersion.historical).to include(historical_version)
        expect(PromptVersion.historical).not_to include(current_version)
      end
    end

    describe '.ordered' do
      it 'orders by version number' do
        versions = prompt.prompt_versions.ordered
        expect(versions.first.version_number).to be < versions.last.version_number
      end
    end

    describe '.recent_first' do
      it 'orders by version number desc' do
        versions = prompt.prompt_versions.recent_first
        expect(versions.first.version_number).to be > versions.last.version_number
      end
    end
  end

  describe 'instance methods' do
    let(:prompt) { create(:prompt) }
    let(:admin_user) { create(:admin_user) }
    
    before do
      # Create additional versions
      prompt.create_version!(created_by: admin_user, change_summary: 'Version 2')
      prompt.create_version!(created_by: admin_user, change_summary: 'Version 3')
    end

    let(:version_2) { prompt.prompt_versions.find_by(version_number: 2) }
    let(:version_3) { prompt.prompt_versions.find_by(version_number: 3) }

    describe '#previous_version' do
      it 'returns the previous version' do
        expect(version_3.previous_version).to eq(version_2)
      end

      it 'returns nil for first version' do
        version_1 = prompt.prompt_versions.find_by(version_number: 1)
        expect(version_1.previous_version).to be_nil
      end
    end

    describe '#next_version' do
      it 'returns the next version' do
        expect(version_2.next_version).to eq(version_3)
      end

      it 'returns nil for latest version' do
        expect(version_3.next_version).to be_nil
      end
    end

    describe '#is_latest?' do
      it 'returns true for latest version' do
        expect(version_3.is_latest?).to be true
      end

      it 'returns false for older version' do
        expect(version_2.is_latest?).to be false
      end
    end

    describe '#content_diff_from_previous' do
      it 'returns diff information' do
        diff = version_2.content_diff_from_previous
        expect(diff).to have_key(:previous_content)
        expect(diff).to have_key(:current_content)
        expect(diff).to have_key(:changes)
      end

      it 'returns nil for first version' do
        version_1 = prompt.prompt_versions.find_by(version_number: 1)
        expect(version_1.content_diff_from_previous).to be_nil
      end
    end

    describe '#restore!' do
      it 'reverts prompt to this version' do
        original_content = version_2.content
        expect(prompt).to receive(:revert_to_version!).with(
          version_2.version_number,
          reverted_by: prompt.updated_by,
          change_summary: "Restored from version #{version_2.version_number}"
        )
        version_2.restore!
      end
    end

    describe '#summary' do
      it 'returns change_summary when present' do
        version_2.change_summary = 'Custom summary'
        expect(version_2.summary).to eq('Custom summary')
      end

      it 'returns default summary when change_summary is blank' do
        version_2.change_summary = nil
        expect(version_2.summary).to eq("Version #{version_2.version_number}")
      end
    end

    describe '#created_by_name' do
      it 'returns creator email' do
        expect(version_2.created_by_name).to eq(admin_user.email)
      end

      it 'returns Unknown when created_by is nil' do
        version_2.created_by = nil
        expect(version_2.created_by_name).to eq('Unknown')
      end
    end

    describe '#age' do
      it 'returns time difference from creation' do
        travel_to 1.hour.from_now do
          expect(version_2.age).to be_within(1.second).of(1.hour)
        end
      end
    end

    describe '#formatted_age' do
      it 'formats age in seconds' do
        travel_to 30.seconds.from_now do
          expect(version_2.formatted_age).to match(/\d+ seconds ago/)
        end
      end

      it 'formats age in minutes' do
        travel_to 5.minutes.from_now do
          expect(version_2.formatted_age).to match(/\d+ minutes ago/)
        end
      end

      it 'formats age in hours' do
        travel_to 3.hours.from_now do
          expect(version_2.formatted_age).to match(/\d+ hours ago/)
        end
      end

      it 'formats age in days' do
        travel_to 2.days.from_now do
          expect(version_2.formatted_age).to match(/\d+ days ago/)
        end
      end
    end
  end

  describe 'factory traits' do
    it 'creates historical version' do
      prompt = create(:prompt)
      version = create(:prompt_version, :historical, prompt: prompt)
      expect(version.is_current).to be false
    end

    it 'creates current version' do
      prompt = create(:prompt)
      version = create(:prompt_version, :current, prompt: prompt)
      expect(version.is_current).to be true
    end

    it 'creates version 2' do
      prompt = create(:prompt)
      version = create(:prompt_version, :version_2, prompt: prompt)
      expect(version.version_number).to eq(2)
    end

    it 'creates version with metadata' do
      prompt = create(:prompt)
      version = create(:prompt_version, :with_metadata, prompt: prompt)
      expect(version.metadata).to have_key('performance_notes')
    end

    it 'creates major change version' do
      prompt = create(:prompt)
      version = create(:prompt_version, :major_change, prompt: prompt)
      expect(version.change_summary).to include('Major rewrite')
    end
  end
end
