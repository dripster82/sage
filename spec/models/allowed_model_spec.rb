# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AllowedModel, type: :model do
  subject { build(:allowed_model) }

  it_behaves_like 'an ActiveRecord model'

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:model) }
    it { should validate_uniqueness_of(:model) }
    it { should validate_presence_of(:provider) }
    it { should validate_inclusion_of(:active).in_array([true, false]) }
    it { should validate_inclusion_of(:default).in_array([true, false]) }
    
    it 'validates context_size is positive when present' do
      model = build(:allowed_model, context_size: -1)
      expect(model).not_to be_valid
      expect(model.errors[:context_size]).to include('must be greater than 0')
    end

    it 'allows nil context_size' do
      model = build(:allowed_model, context_size: nil)
      expect(model).to be_valid
    end
  end

  describe 'scopes' do
    let!(:active_model) { create(:allowed_model, active: true) }
    let!(:inactive_model) { create(:allowed_model, active: false) }
    let!(:default_model) { create(:allowed_model, default: true) }
    let!(:openai_model) { create(:allowed_model, :openai) }

    describe '.active' do
      it 'returns only active models' do
        expect(AllowedModel.active).to include(active_model)
        expect(AllowedModel.active).not_to include(inactive_model)
      end
    end

    describe '.inactive' do
      it 'returns only inactive models' do
        expect(AllowedModel.inactive).to include(inactive_model)
        expect(AllowedModel.inactive).not_to include(active_model)
      end
    end

    describe '.default_model' do
      it 'returns only default models' do
        expect(AllowedModel.default_model).to include(default_model)
        expect(AllowedModel.default_model).not_to include(active_model)
      end
    end

    describe '.by_provider' do
      it 'filters by provider when provided' do
        results = AllowedModel.by_provider('openai')
        expect(results).to include(openai_model)
      end

      it 'returns all when provider is blank' do
        results = AllowedModel.by_provider('')
        expect(results.count).to eq(AllowedModel.count)
      end
    end
  end

  describe 'callbacks' do
    describe '#ensure_single_default' do
      it 'removes default from other models when setting a model as default' do
        model1 = create(:allowed_model, default: true)
        model2 = create(:allowed_model, default: false)

        model2.update!(default: true)

        expect(model1.reload.default).to be false
        expect(model2.reload.default).to be true
      end

      it 'does not affect other models when setting default to false' do
        model1 = create(:allowed_model, default: true)
        model2 = create(:allowed_model, default: false)

        model1.update!(default: false)

        expect(model1.reload.default).to be false
        expect(model2.reload.default).to be false
      end
    end
  end

  describe 'class methods' do
    describe '.available_models_for_dropdown' do
      before do
        allow(RubyLLM).to receive(:models).and_return([
          double(name: 'Test Model', id: 'test/model', provider: 'test', context_window: 4096)
        ])
      end

      it 'returns formatted model data from RubyLLM' do
        result = AllowedModel.available_models_for_dropdown
        expect(result).to eq([
          { name: 'Test Model', id: 'test/model', provider: 'test', context_size: 4096 }
        ])
      end
    end

    describe '.get_default_model' do
      it 'returns the active default model' do
        default_model = create(:allowed_model, default: true, active: true)
        create(:allowed_model, default: false, active: true)

        expect(AllowedModel.get_default_model).to eq(default_model)
      end

      it 'returns nil if no active default model exists' do
        create(:allowed_model, default: true, active: false)
        create(:allowed_model, default: false, active: true)

        expect(AllowedModel.get_default_model).to be_nil
      end
    end

    describe '.get_fallback_model' do
      before do
        allow(RubyLLM.config).to receive(:default_model).and_return('ruby-llm/default')
      end

      it 'returns the default allowed model first' do
        default_model = create(:allowed_model, default: true, active: true)
        create(:allowed_model, model: 'ruby-llm/default', active: true)

        expect(AllowedModel.get_fallback_model).to eq(default_model)
      end

      it 'returns RubyLLM default model if it exists in allowed models' do
        ruby_llm_model = create(:allowed_model, model: 'ruby-llm/default', active: true)
        create(:allowed_model, default: false, active: true)

        expect(AllowedModel.get_fallback_model).to eq(ruby_llm_model)
      end

      it 'returns first active model as last resort' do
        first_model = create(:allowed_model, active: true)
        create(:allowed_model, active: true)

        expect(AllowedModel.get_fallback_model).to eq(first_model)
      end

      it 'returns nil if no active models exist' do
        create(:allowed_model, active: false)

        expect(AllowedModel.get_fallback_model).to be_nil
      end
    end
  end

  describe 'instance methods' do
    let(:model) { build(:allowed_model, name: 'Test Model', provider: 'test') }

    describe '#display_name' do
      it 'returns formatted name with provider' do
        expect(model.display_name).to eq('Test Model (test)')
      end
    end

    describe '#context_size_display' do
      it 'returns formatted size for millions' do
        model.context_size = 1_500_000
        expect(model.context_size_display).to eq('1.5M')
      end

      it 'returns formatted size for thousands' do
        model.context_size = 128_000
        expect(model.context_size_display).to eq('128.0K')
      end

      it 'returns raw number for smaller sizes' do
        model.context_size = 512
        expect(model.context_size_display).to eq('512')
      end

      it 'returns Unknown for nil context_size' do
        model.context_size = nil
        expect(model.context_size_display).to eq('Unknown')
      end
    end

    describe '#is_default?' do
      it 'returns true when model is default' do
        model.default = true
        expect(model.is_default?).to be true
      end

      it 'returns false when model is not default' do
        model.default = false
        expect(model.is_default?).to be false
      end
    end

    describe '#make_default!' do
      it 'sets this model as default and removes default from others' do
        model1 = create(:allowed_model, default: true)
        model2 = create(:allowed_model, default: false)

        model2.make_default!

        expect(model1.reload.default).to be false
        expect(model2.reload.default).to be true
      end
    end
  end
end
