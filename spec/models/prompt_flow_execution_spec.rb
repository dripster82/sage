# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PromptFlowExecution, type: :model do
  subject { build(:prompt_flow_execution) }

  it_behaves_like 'an ActiveRecord model'

  describe 'associations' do
    it { should belong_to(:prompt_flow) }
  end

  describe 'validations' do
    it { should validate_inclusion_of(:status).in_array(%w[pending running completed failed]) }

    it 'is valid with default factory' do
      expect(subject).to be_valid
    end
  end
end
