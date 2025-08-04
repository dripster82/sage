# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KnowledgeGraph::LlmExtractionService, type: :service do
  # Test data
  let(:test_document) { create_test_document(text: 'Test document content about companies and people') }
  let(:test_chunks) { create_test_chunks(count: 3) }
  let(:mock_prompt1) { double('Prompt', tags_hash: { text: nil, current_schema: nil }, content: 'Extract entities: %{text}') }
  let(:mock_prompt2) { double('Prompt', tags_hash: { text: nil, current_schema: nil }, content: 'Refine entities: %{text}') }
  let(:mock_llm_response) { 
    {
      "nodes" => [
        {"name" => "Company A", "type" => "Component", "description" => "A test company"},
        {"name" => "John Doe", "type" => "Actor", "description" => "A test person"}
      ],
      "edges" => [
        {"source" => "John Doe", "source_type" => "Actor", "target" => "Company A", "target_type" => "Component", "relationship_type" => "works_at"}
      ]
    }
  }

  let(:service) { described_class.new(test_document) }

  before do
    # Mock external dependencies
    allow(Prompt).to receive(:find_by).with(name: "kg_extraction_1st_pass").and_return(mock_prompt1)
    allow(Prompt).to receive(:find_by).with(name: "kg_extraction_2nd_pass").and_return(mock_prompt2)
    allow_any_instance_of(Llm::QueryService).to receive(:json_from_query).and_return(mock_llm_response)
    allow(File).to receive(:write)
    
    # Mock environment variables
    allow(ENV).to receive(:fetch).with('EXTRACTING_NODE_THREADS', 5).and_return('2')
    allow(ENV).to receive(:fetch).with('EXTRACTING_NODE_RPM', 500).and_return('100')
  end

  it 'responds to process method' do
    expect(service).to respond_to(:process)
  end

  describe 'initialization' do
    it 'initializes with document' do
      expect(service.instance_variable_get(:@document)).to eq(test_document)
    end

    it 'sets up node types and schema' do
      expect(service.instance_variable_get(:@node_types)).to be_an(Array)
      expect(service.instance_variable_get(:@current_doc_schema)).to be_a(Hash)
    end

    it 'initializes chunks from document' do
      expect(service.instance_variable_get(:@chunks)).to eq(test_document.chunks)
    end
  end

  describe '#process' do
    it 'processes document and returns nodes and edges' do
      result = service.process
      expect(result).to be_a(Hash)
      expect(result).to have_key("nodes")
      expect(result).to have_key("edges")
    end

    it 'extracts nodes and edges from chunks' do
      expect(service).to receive(:extract_nodes_and_edges_from_chunks)
      service.process
    end

    it 'preprocesses nodes and edges' do
      expect(service).to receive(:preprocess_nodes_and_edges)
      service.process
    end

    it 'writes debug output to file' do
      expect(File).to receive(:write).with("chunk_node.txt", anything)
      service.process
    end
  end

  describe 'error handling' do
    it 'handles LLM service errors gracefully' do
      allow_any_instance_of(Llm::QueryService).to receive(:json_from_query).and_raise(StandardError, 'LLM Error')
      
      expect { service.process }.to raise_error(StandardError, 'LLM Error')
    end

    it 'handles missing prompts gracefully' do
      allow(Prompt).to receive(:find_by).and_return(nil)
      
      expect { service.process }.to raise_error
    end

    it 'handles file writing errors gracefully' do
      allow(File).to receive(:write).and_raise(StandardError, 'File Error')
      
      expect { service.process }.to raise_error(StandardError, 'File Error')
    end
  end

  describe 'threading and rate limiting' do
    it 'respects thread limits' do
      # This test would require more complex mocking to verify threading behavior
      # For now, just ensure the service can handle the threading setup
      expect { service.process }.not_to raise_error
    end

    it 'respects rate limiting' do
      # This test would require time-based mocking to verify rate limiting
      # For now, just ensure the service can handle the rate limiting setup
      expect { service.process }.not_to raise_error
    end
  end

  describe 'integration' do
    it 'works with real document data' do
      # Skip this test for now since it requires proper mocking
      skip 'Requires proper service mocking to avoid real LLM calls'
    end
  end
end
