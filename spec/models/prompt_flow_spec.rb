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
    it { should validate_inclusion_of(:status).in_array(%w[draft valid invalid]) }
    it { should validate_numericality_of(:version_number).is_greater_than(0) }
    it { should validate_uniqueness_of(:version_number).scoped_to(:name) }
    it { should validate_numericality_of(:max_executions).is_greater_than(0) }
    it { should validate_numericality_of(:credits).is_greater_than(0) }

    it 'is valid with default factory' do
      expect(subject).to be_valid
    end
  end

  describe '#duplicate_as_draft!' do
    it 'creates a new draft version with incremented version number' do
      admin = create(:admin_user)
      flow = create(:prompt_flow, version_number: 1, is_current: true, graph_json: { 'nodes' => [], 'edges' => [] })

      draft = flow.duplicate_as_draft!(admin)

      expect(draft).to be_persisted
      expect(draft.name).to eq(flow.name)
      expect(draft.version_number).to eq(2)
      expect(draft.is_current).to be(false)
      expect(draft.status).to eq('draft')
      expect(draft.graph_json).to eq(flow.graph_json)
      expect(draft.created_by).to eq(admin)
      expect(draft.updated_by).to eq(admin)
    end
  end

  describe '#sync_graph_to_nodes_and_edges!' do
    it 'creates nodes and edges from graph_json, skipping start nodes' do
      flow = create(:prompt_flow, graph_json: {
        'nodes' => [
          { 'id' => 'start', 'node_type' => 'start', 'position_x' => 10, 'position_y' => 10, 'output_ports' => { 'flow' => {} } },
          { 'id' => 'input-1', 'node_type' => 'input', 'position_x' => 20, 'position_y' => 20, 'output_ports' => { 'query' => {} } },
          { 'id' => 'output-1', 'node_type' => 'output', 'position_x' => 40, 'position_y' => 40, 'input_ports' => { 'response' => {} } }
        ],
        'edges' => [
          { 'source_node_id' => 'start', 'target_node_id' => 'input-1', 'source_port' => 'flow', 'target_port' => 'flow' },
          { 'source_node_id' => 'input-1', 'target_node_id' => 'output-1', 'source_port' => 'query', 'target_port' => 'response' }
        ]
      })

      expect { flow.sync_graph_to_nodes_and_edges! }
        .to change(flow.nodes, :count).by(2)
        .and change(flow.edges, :count).by(1)

      edge = flow.edges.first
      expect(edge.source_port).to eq('query')
      expect(edge.target_port).to eq('response')
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
