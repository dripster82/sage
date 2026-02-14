# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PromptFlow, type: :model do
  subject { build(:prompt_flow) }

  it_behaves_like 'an ActiveRecord model'

  describe 'associations' do
    it { should belong_to(:created_by).class_name('AdminUser') }
    it { should belong_to(:updated_by).class_name('AdminUser') }
    it { should have_many(:nodes).class_name('PromptFlowNode').dependent(:destroy) }
    it { should have_many(:edges).class_name('PromptFlowEdge').dependent(:destroy) }
    it { should have_many(:executions).class_name('PromptFlowExecution').dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_inclusion_of(:status).in_array(%w[draft valid invalid]) }
    it { should validate_numericality_of(:version_number).is_greater_than(0) }
    it { should validate_numericality_of(:max_executions).is_greater_than(0) }

    it 'is valid with default factory' do
      expect(subject).to be_valid
    end
  end

  describe 'dependent destroys' do
    it 'removes nodes, edges, and executions when flow is destroyed' do
      flow = create(:prompt_flow)
      source = create(:prompt_flow_node, prompt_flow: flow)
      target = create(:prompt_flow_node, :output_node, prompt_flow: flow)
      create(:prompt_flow_edge, prompt_flow: flow, source_node: source, target_node: target)
      create(:prompt_flow_execution, prompt_flow: flow)

      expect { flow.destroy }.to change(PromptFlowNode, :count).by(-2)
        .and change(PromptFlowEdge, :count).by(-1)
        .and change(PromptFlowExecution, :count).by(-1)
    end
  end
end
