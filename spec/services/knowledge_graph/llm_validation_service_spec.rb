# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KnowledgeGraph::LlmValidationService, type: :service do
  # Test data
  let(:nodes_and_edges) {
    {
      "nodes" => [
        {"name" => "Company A", "type" => "Component", "description" => "A test company"},
        {"name" => "John Doe", "type" => "Actor", "description" => "A test person"},
        {"name" => "Old Company", "type" => "Component", "description" => "Company to be replaced"}
      ],
      "edges" => [
        {"source" => "John Doe", "source_type" => "Actor", "target" => "Company A", "target_type" => "Component", "relationship_type" => "works_at"},
        {"source" => "Old Company", "source_type" => "Component", "target" => "John Doe", "target_type" => "Actor", "relationship_type" => "employs"}
      ]
    }
  }

  let(:mock_prompt) { double('Prompt', tags_hash: { nodes: nil }, content: 'Validate nodes: %{nodes}') }
  let(:mock_node_mapping) {
    [
      {
        "orig_node" => {"name" => "Old Company", "type" => "Component"},
        "new_node" => {"name" => "Company A", "type" => "Component"}
      }
    ]
  }

  let(:service) { described_class.new(nodes_and_edges) }

  before do
    # Mock external dependencies
    allow(Prompt).to receive(:find_by).with(name: "kg_node_validation").and_return(mock_prompt)
    allow_any_instance_of(Llm::QueryService).to receive(:json_from_query).and_return(mock_node_mapping)
  end

  it 'responds to validate_nodes method' do
    expect(service).to respond_to(:validate_nodes)
  end

  describe 'initialization' do
    it 'initializes with nodes and edges' do
      expect(service.instance_variable_get(:@nodes_and_edges)).to eq(nodes_and_edges)
    end

    it 'sets up model configuration' do
      expect(service.instance_variable_get(:@model)).to eq("anthropic/claude-3.5-haiku")
    end
  end

  describe '#validate_nodes' do
    it 'validates nodes and returns processed data' do
      result = service.validate_nodes
      expect(result).to be_a(Hash)
      expect(result).to have_key("nodes")
      expect(result).to have_key("edges")
    end

    it 'calls LLM validation service' do
      expect(service).to receive(:validate_nodes_with_llm)
      service.validate_nodes
    end

    it 'cleans up nodes after validation' do
      expect(service).to receive(:cleanup_nodes)
      service.validate_nodes
    end
  end

  describe '#validate_nodes_with_llm' do
    it 'uses the correct prompt' do
      expect(Prompt).to receive(:find_by).with(name: "kg_node_validation")
      service.send(:validate_nodes_with_llm)
    end

    it 'calls LLM service with correct parameters' do
      expect_any_instance_of(Llm::QueryService).to receive(:json_from_query)
      service.send(:validate_nodes_with_llm)
    end
  end

  describe '#cleanup_nodes' do
    before do
      service.instance_variable_set(:@node_mapping, mock_node_mapping)
    end

    it 'processes node mappings correctly' do
      result = service.send(:cleanup_nodes)
      expect(result).to be_a(Hash)
    end

    it 'removes duplicate nodes' do
      original_node_count = nodes_and_edges["nodes"].length
      result = service.send(:cleanup_nodes)
      # Should have fewer nodes after cleanup due to merging
      expect(result["nodes"].length).to be <= original_node_count
    end

    it 'updates edge references' do
      result = service.send(:cleanup_nodes)
      # Check that edges are updated to reference new node names
      expect(result["edges"]).to be_an(Array)
    end

    it 'handles empty node mapping' do
      service.instance_variable_set(:@node_mapping, [])
      result = service.send(:cleanup_nodes)
      expect(result).to eq(nodes_and_edges)
    end

    it 'handles nil node mapping' do
      service.instance_variable_set(:@node_mapping, nil)
      result = service.send(:cleanup_nodes)
      expect(result).to eq(nodes_and_edges)
    end
  end

  describe 'error handling' do
    it 'handles LLM service errors gracefully' do
      allow_any_instance_of(Llm::QueryService).to receive(:json_from_query).and_raise(StandardError, 'LLM Error')
      
      expect { service.validate_nodes }.to raise_error(StandardError, 'LLM Error')
    end

    it 'handles missing prompts gracefully' do
      allow(Prompt).to receive(:find_by).and_return(nil)
      
      expect { service.validate_nodes }.to raise_error
    end

    it 'handles malformed node mapping data' do
      allow_any_instance_of(Llm::QueryService).to receive(:json_from_query).and_return("invalid data")
      
      expect { service.validate_nodes }.to raise_error
    end
  end

  describe 'node merging logic' do
    let(:complex_nodes_and_edges) {
      {
        "nodes" => [
          {"name" => "Company A", "type" => "Component", "description" => "Original company", "attributes" => {"size" => "large"}},
          {"name" => "Company B", "type" => "Component", "description" => "Duplicate company", "attributes" => {"location" => "NYC"}},
          {"name" => "John Doe", "type" => "Actor", "description" => "A person"}
        ],
        "edges" => [
          {"source" => "John Doe", "source_type" => "Actor", "target" => "Company A", "target_type" => "Component", "relationship_type" => "works_at"},
          {"source" => "Company B", "source_type" => "Component", "target" => "John Doe", "target_type" => "Actor", "relationship_type" => "employs"}
        ]
      }
    }

    let(:complex_mapping) {
      [
        {
          "orig_node" => {"name" => "Company B", "type" => "Component"},
          "new_node" => {"name" => "Company A", "type" => "Component"}
        }
      ]
    }

    it 'merges node attributes correctly' do
      service = described_class.new(complex_nodes_and_edges)
      service.instance_variable_set(:@node_mapping, complex_mapping)
      
      result = service.send(:cleanup_nodes)
      
      # Find the merged company node
      company_node = result["nodes"].find { |n| n["name"] == "Company A" && n["type"] == "Component" }
      expect(company_node).not_to be_nil
      expect(company_node["attributes"]).to include("size" => "large", "location" => "NYC")
    end
  end
end
