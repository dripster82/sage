# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationRecord, type: :model do
  # Since ApplicationRecord is abstract, we'll test it through a concrete model
  let(:concrete_model) { AiLog }
  
  describe 'class methods' do
    describe '.ransackable_attributes' do
      it 'responds to ransackable_attributes' do
        expect(concrete_model).to respond_to(:ransackable_attributes)
      end

      it 'calls authorizable_ransackable_attributes' do
        expect(concrete_model).to receive(:authorizable_ransackable_attributes)
        concrete_model.ransackable_attributes
      end

      it 'accepts auth_object parameter' do
        auth_object = double('auth_object')
        expect(concrete_model).to receive(:authorizable_ransackable_attributes)
        concrete_model.ransackable_attributes(auth_object)
      end
    end

    describe '.ransackable_associations' do
      it 'responds to ransackable_associations' do
        expect(concrete_model).to respond_to(:ransackable_associations)
      end

      it 'calls authorizable_ransackable_associations' do
        expect(concrete_model).to receive(:authorizable_ransackable_associations)
        concrete_model.ransackable_associations
      end

      it 'accepts auth_object parameter' do
        auth_object = double('auth_object')
        expect(concrete_model).to receive(:authorizable_ransackable_associations)
        concrete_model.ransackable_associations(auth_object)
      end
    end
  end

  describe 'inheritance' do
    it 'inherits from ActiveRecord::Base' do
      expect(ApplicationRecord.superclass).to eq(ActiveRecord::Base)
    end

    it 'is marked as primary abstract class' do
      expect(ApplicationRecord.abstract_class?).to be true
    end
  end

  describe 'concrete model inheritance' do
    it 'concrete models inherit from ApplicationRecord' do
      expect(AiLog.superclass).to eq(ApplicationRecord)
      expect(AdminUser.superclass).to eq(ApplicationRecord)
      expect(Prompt.superclass).to eq(ApplicationRecord)
      expect(PromptVersion.superclass).to eq(ApplicationRecord)
    end
  end

  describe 'ransack integration' do
    # Test that ransack methods are properly inherited by concrete models
    context 'with AiLog model' do
      it 'has ransackable attributes' do
        # This tests that the ransack integration works
        expect { AiLog.ransackable_attributes }.not_to raise_error
      end

      it 'has ransackable associations' do
        expect { AiLog.ransackable_associations }.not_to raise_error
      end
    end

    context 'with Prompt model' do
      it 'has ransackable attributes' do
        expect { Prompt.ransackable_attributes }.not_to raise_error
      end

      it 'has ransackable associations' do
        expect { Prompt.ransackable_associations }.not_to raise_error
      end
    end
  end
end
