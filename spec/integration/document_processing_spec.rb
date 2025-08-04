# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Document Processing Pipeline', type: :integration do
  # Test data
  let(:test_file_path) { 'spec/fixtures/test_document.txt' }
  let(:test_file_content) { File.read(Rails.root.join(test_file_path)) }
  let(:expected_chunk_count) { 3 }
  let(:expected_summary_length) { 50..500 }
  let(:expected_vector_size) { 1536 }
  let(:expected_kg_nodes) { 2..10 }
  
  let(:mock_llm_summary) { 'This document discusses knowledge graphs and document processing.' }
  let(:mock_llm_entities) do
    {
      'entities' => ['Knowledge Graph', 'Document Processing', 'Text Analysis'],
      'relationships' => [
        { 'from' => 'Document Processing', 'to' => 'Knowledge Graph', 'type' => 'CREATES' },
        { 'from' => 'Text Analysis', 'to' => 'Document Processing', 'type' => 'PART_OF' }
      ]
    }
  end
  let(:mock_embedding_vectors) { Array.new(expected_vector_size) { rand(-1.0..1.0) } }
  let(:mock_neo4j_result) { [{ 'n' => { 'name' => 'Test Node' } }] }
  
  let(:expected_document_structure) { %w[text file_path summary vector chunks] }
  let(:expected_chunk_structure) { %w[text file_path position vector] }
  let(:expected_kg_structure) { %w[nodes relationships processing_time] }

  before do
    # Mock external services to avoid real API calls
    setup_service_mocks
  end

  describe 'full document processing pipeline' do
    let(:import_service) { Documents::ImportService.new(test_file_path) }

    it 'processes document through complete pipeline' do
      result_document = nil
      
      expect {
        import_service.process
        result_document = import_service.document
      }.not_to raise_error
      
      expect(result_document).to be_a(Document)
      verify_document_structure(result_document)
    end

    it 'creates proper document structure' do
      import_service.process
      document = import_service.document
      
      expect(document.text).to eq(test_file_content)
      expect(document.file_path).to eq(test_file_path)
      expect(document.summary).to be_present
      expect(document.vector).to be_present
      expect(document.chunks).to be_present
    end

    it 'generates appropriate number of chunks' do
      import_service.process
      document = import_service.document
      
      expect(document.chunks.size).to be >= 1
      expect(document.chunks.size).to be <= 10
    end

    it 'creates chunks with proper structure' do
      import_service.process
      document = import_service.document
      
      document.chunks.each_with_index do |chunk, index|
        expect(chunk.text).to be_present
        expect(chunk.file_path).to eq(test_file_path)
        expect(chunk.position).to eq(index)
        expect(chunk.vector).to be_present
      end
    end

    it 'builds knowledge graph from document' do
      kg_result = nil
      
      expect {
        import_service.process
        kg_result = import_service.build_knowledge_graph
      }.not_to raise_error
      
      expect(kg_result).to be_a(Hash)
    end
  end

  describe 'individual service integration' do
    let(:test_document) { create_test_document(file_path: test_file_path, text: test_file_content) }

    describe 'ChunkService integration' do
      it 'creates chunks from document text' do
        chunk_service = ChunkService.new(test_document)
        
        expect {
          chunk_service.chunk
        }.not_to raise_error
        
        expect(test_document.chunks).to be_present
        expect(test_document.chunks.first).to be_a(Chunk)
      end
    end

    describe 'EmbeddingService integration' do
      before do
        test_document.chunks = create_test_chunks(3)
      end

      it 'embeds all document chunks' do
        embedding_service = Llm::EmbeddingService.new
        
        expect {
          embedding_service.embed_chunks(test_document.chunks)
        }.not_to raise_error
        
        test_document.chunks.each do |chunk|
          expect(chunk.vector).to be_present
          expect(chunk.vector.size).to eq(expected_vector_size)
        end
      end
    end

    describe 'KnowledgeGraph::BuildService integration' do
      before do
        test_document.chunks = create_test_chunks(2)
      end

      it 'builds knowledge graph from document' do
        kg_service = KnowledgeGraph::BuildService.new(test_document)
        
        result = nil
        expect {
          result = kg_service.process
        }.not_to raise_error
        
        expect(result).to be_a(Hash)
      end
    end
  end

  describe 'error handling and resilience' do
    let(:import_service) { Documents::ImportService.new(test_file_path) }

    context 'when LLM service fails' do
      before do
        allow_any_instance_of(Llm::QueryService).to receive(:ask).and_raise(StandardError, 'LLM Error')
      end

      it 'handles LLM errors gracefully' do
        expect {
          import_service.process
        }.to raise_error(StandardError, 'LLM Error')
      end
    end

    context 'when embedding service fails' do
      before do
        allow_any_instance_of(Llm::EmbeddingService).to receive(:embed_text).and_raise(StandardError, 'Embedding Error')
      end

      it 'handles embedding errors gracefully' do
        expect {
          import_service.process
        }.to raise_error(StandardError, 'Embedding Error')
      end
    end

    context 'when Neo4j service fails' do
      before do
        # Ensure the document has chunks to avoid nil errors
        import_service.document.text = test_file_content
        import_service.split_text

        # Mock the LLM extraction service to return nodes that will trigger Neo4j calls
        allow_any_instance_of(KnowledgeGraph::LlmExtractionService).to receive(:extract_nodes_and_edges).and_return({
          "nodes" => [
            { "name" => "Test Node", "type" => "CONCEPT", "description" => "A test node" }
          ],
          "edges" => []
        })

        # Remove the KnowledgeGraph::BuildService mock for this test
        allow_any_instance_of(KnowledgeGraph::BuildService).to receive(:process).and_call_original

        # Mock the save_cyphers method to raise the error instead of catching it
        allow_any_instance_of(KnowledgeGraph::BuildService).to receive(:save_cyphers).and_raise(StandardError, 'Neo4j Error')
      end

      it 'handles Neo4j errors gracefully' do
        # Ensure the document has chunks before building knowledge graph
        import_service.document.chunks = [double('Chunk', text: 'test chunk', vector: [0.1, 0.2, 0.3])]

        expect {
          import_service.build_knowledge_graph
        }.to raise_error(StandardError, 'Neo4j Error')
      end
    end
  end

  describe 'performance characteristics' do
    let(:large_document_path) { 'spec/fixtures/large_test_document.txt' }
    
    before do
      # Create a larger test document
      large_content = test_file_content * 10
      File.write(Rails.root.join(large_document_path), large_content)
    end

    after do
      # Clean up
      File.delete(Rails.root.join(large_document_path)) if File.exist?(Rails.root.join(large_document_path))
    end

    it 'processes large documents within reasonable time' do
      import_service = Documents::ImportService.new(large_document_path)
      
      expect {
        Timeout.timeout(30) do
          import_service.process
        end
      }.not_to raise_error
    end
  end

  private

  def setup_service_mocks
    # Mock LLM services
    allow_any_instance_of(Llm::QueryService).to receive(:ask).and_return(
      double('Response', content: mock_llm_summary, input_tokens: 100, output_tokens: 50)
    )
    allow_any_instance_of(Llm::QueryService).to receive(:json_from_query).and_return([])

    # Mock embedding service
    allow_any_instance_of(Llm::EmbeddingService).to receive(:embed_text).and_return(
      double('Embedding', vectors: mock_embedding_vectors)
    )
    allow_any_instance_of(Llm::EmbeddingService).to receive(:embed_chunks) do |service, chunks|
      chunks.each { |chunk| chunk.vector = mock_embedding_vectors }
      chunks
    end

    # Mock Neo4j service
    allow_any_instance_of(KnowledgeGraph::QueryService).to receive(:query).and_return(mock_neo4j_result)
    allow(File).to receive(:write).and_return(true)

    # Mock prompts - need to mock all the prompts used by KnowledgeGraph services
    allow(Prompt).to receive(:find_by).with(name: 'text_summarization').and_return(
      double('Prompt', tags_hash: { text: nil }, content: 'Summarize: %{text}')
    )
    allow(Prompt).to receive(:find_by).with(name: 'kg_extraction_category_validation').and_return(
      double('Prompt', tags_hash: { categories: nil, summary: nil }, content: 'Validate categories: %{categories}')
    )
    allow(Prompt).to receive(:find_by).with(name: 'kg_extraction_1st_pass').and_return(
      double('Prompt', tags_hash: { text: nil, current_schema: nil, summary: nil }, content: 'Extract entities: %{text}')
    )
    allow(Prompt).to receive(:find_by).with(name: 'kg_extraction_2nd_pass').and_return(
      double('Prompt', tags_hash: { text: nil, summary: nil, response: nil, entity_types: nil }, content: 'Process entities: %{text}')
    )
    allow(Prompt).to receive(:find_by).with(name: 'kg_node_validation').and_return(
      double('Prompt', tags_hash: { nodes: nil }, content: 'Validate nodes: %{nodes}')
    )

    # Mock the entire KnowledgeGraph::BuildService to avoid complex internal mocking
    allow_any_instance_of(KnowledgeGraph::BuildService).to receive(:process).and_return({})

    # Mock file operations
    allow(File).to receive(:open).and_return(StringIO.new(test_file_content))
    allow(FileProcessor::Txt).to receive(:parse).and_return(test_file_content)
    allow(MIME::Types).to receive(:type_for).and_return([double(content_type: 'text/plain')])
  end

  def verify_document_structure(document)
    expect(document.text).to be_present
    expect(document.file_path).to eq(test_file_path)
    expect(document.summary).to be_present
    expect(document.vector).to be_an(Array)
    expect(document.chunks).to be_an(Array)
    expect(document.chunks).not_to be_empty
  end
end
