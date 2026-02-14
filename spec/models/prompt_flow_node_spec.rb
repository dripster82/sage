# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PromptFlowNode, type: :model do
  subject { build(:prompt_flow_node) }

  it_behaves_like 'an ActiveRecord model'

  describe 'associations' do
    it { should belong_to(:prompt_flow) }
    it { should belong_to(:prompt).optional }
  end

  describe 'validations' do
    it { should validate_inclusion_of(:node_type).in_array(%w[input prompt output]) }

    context 'when node_type is prompt' do
      it 'requires a prompt' do
        node = build(:prompt_flow_node, node_type: 'prompt', prompt: nil)
        expect(node).not_to be_valid
        expect(node.errors[:prompt_id]).to include('must be present for prompt nodes')
      end
    end

    context 'when node_type is input' do
      it 'does not require a prompt' do
        node = build(:prompt_flow_node, node_type: 'input', prompt: nil)
        expect(node).to be_valid
      end
    end
  end
end
