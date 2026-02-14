# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PromptFlowEdge, type: :model do
  subject { build(:prompt_flow_edge) }

  it_behaves_like 'an ActiveRecord model'

  describe 'associations' do
    it { should belong_to(:prompt_flow) }
    it { should belong_to(:source_node).class_name('PromptFlowNode') }
    it { should belong_to(:target_node).class_name('PromptFlowNode') }
  end

  describe 'validations' do
    it { should validate_presence_of(:source_port) }
    it { should validate_presence_of(:target_port) }

    it 'rejects self-edges' do
      node = create(:prompt_flow_node)
      edge = build(:prompt_flow_edge, prompt_flow: node.prompt_flow, source_node: node, target_node: node)
      expect(edge).not_to be_valid
      expect(edge.errors[:target_node_id]).to include('cannot be the same as source node')
    end

    it 'requires nodes to belong to the same flow' do
      source = create(:prompt_flow_node)
      target = create(:prompt_flow_node)
      edge = build(:prompt_flow_edge, prompt_flow: source.prompt_flow, source_node: source, target_node: target)
      expect(edge).not_to be_valid
      expect(edge.errors[:base]).to include('source and target nodes must belong to the same prompt flow')
    end
  end
end
