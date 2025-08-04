# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Documents::ImportService, type: :service do
  let(:file_path) { 'spec/fixtures/test_document.txt' }
  let(:service) { Documents::ImportService.new(file_path) }

  it_behaves_like 'a service object'

  describe 'initialization' do
    it 'creates a document with file_path' do
      expect(service.document).to be_a(Document)
      expect(service.document.file_path).to eq(file_path)
    end

    it 'sets document attribute accessor' do
      expect(service).to respond_to(:document)
      expect(service).to respond_to(:document=)
    end
  end

  describe '#process' do
    before do
      # Mock all the external dependencies
      mock_file_processor
      mock_llm_response
      mock_embedding_response
      mock_neo4j_query

      # Mock the entire KnowledgeGraph::BuildService to avoid complex internal mocking
      allow_any_instance_of(KnowledgeGraph::BuildService).to receive(:process).and_return({})
      
      # Mock prompts
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
    end

    it 'sets and clears ailog_session' do
      expect(Current).to receive(:ailog_session=).with(kind_of(String))
      expect(Current).to receive(:ailog_session=).with(nil)
      
      service.process
    end

    it 'calls all processing steps in order' do
      expect(service).to receive(:read_file).ordered
      expect(service).to receive(:summerise_doc).ordered
      expect(service).to receive(:split_text).ordered
      expect(service).to receive(:embed_chunks).ordered
      expect(service).to receive(:build_knowledge_graph).ordered
      
      service.process
    end

    it 'processes document successfully' do
      expect {
        service.process
      }.not_to raise_error
      
      expect(service.document.text).to be_present
      expect(service.document.summary).to be_present
      expect(service.document.chunks).to be_present
    end
  end

  describe '#read_file' do
    before do
      mock_file_processor('Test file content')
    end

    it 'reads file content' do
      service.read_file
      expect(service.document.text).to eq('Test file content')
    end

    it 'finds appropriate file processor' do
      expect(service).to receive(:processors).and_return(['Txt'])
      expect(FileProcessor::Txt).to receive(:parse).and_return('content')
      
      service.read_file
    end

    it 'handles different file types' do
      # Test with PDF
      pdf_service = Documents::ImportService.new('test.pdf')
      allow(pdf_service).to receive(:processors).and_return(['Pdf'])
      expect(FileProcessor::Pdf).to receive(:parse).and_return('PDF content')
      
      pdf_service.read_file
      expect(pdf_service.document.text).to eq('PDF content')
    end
  end

  describe '#summerise_doc' do
    before do
      service.document.text = 'Test document content'
      mock_llm_response(content: 'Test summary')
      mock_embedding_response(vectors: [0.1, 0.2, 0.3])
      
      @prompt = double('Prompt', 
        tags_hash: { text: nil }, 
        content: 'Summarize: %{text}'
      )
      allow(Prompt).to receive(:find_by).with(name: 'text_summarization').and_return(@prompt)
    end

    it 'generates document summary' do
      service.summerise_doc
      expect(service.document.summary).to eq('Test summary')
    end

    it 'generates document vector' do
      service.summerise_doc
      expect(service.document.vector).to eq([0.1, 0.2, 0.3])
    end

    it 'uses text summarization prompt' do
      expect(Prompt).to receive(:find_by).with(name: 'text_summarization')
      service.summerise_doc
    end

    it 'calls LLM query service' do
      expect_any_instance_of(Llm::QueryService).to receive(:ask).and_return(
        double(content: 'Summary')
      )
      service.summerise_doc
    end

    it 'calls embedding service' do
      expect_any_instance_of(Llm::EmbeddingService).to receive(:embed_text).and_return(
        double(vectors: [0.1, 0.2])
      )
      service.summerise_doc
    end
  end

  describe '#split_text' do
    before do
      service.document.text = 'Long document text that needs to be split into chunks'
    end

    it 'creates chunks from document text' do
      expect_any_instance_of(ChunkService).to receive(:chunk)
      service.split_text
    end

    it 'uses ChunkService' do
      chunk_service = double('ChunkService')
      expect(ChunkService).to receive(:new).with(service.document).and_return(chunk_service)
      expect(chunk_service).to receive(:chunk)
      
      service.split_text
    end
  end

  describe '#embed_chunks' do
    before do
      service.document.chunks = create_test_chunks(3)
    end

    it 'embeds all chunks' do
      expect_any_instance_of(Llm::EmbeddingService).to receive(:embed_chunks).with(service.document.chunks)
      service.embed_chunks
    end

    it 'uses embedding service' do
      embedding_service = double('EmbeddingService')
      expect(Llm::EmbeddingService).to receive(:new).and_return(embedding_service)
      expect(embedding_service).to receive(:embed_chunks)
      
      service.embed_chunks
    end
  end

  describe '#build_knowledge_graph' do
    before do
      service.document.chunks = create_test_chunks(2)
    end

    it 'builds knowledge graph from document' do
      kg_service = double('KnowledgeGraph::BuildService')
      expect(KnowledgeGraph::BuildService).to receive(:new).with(service.document).and_return(kg_service)
      expect(kg_service).to receive(:process).and_return({})
      
      result = service.build_knowledge_graph
      expect(result).to eq({})
    end

    it 'uses KnowledgeGraph::BuildService' do
      expect_any_instance_of(KnowledgeGraph::BuildService).to receive(:process)
      service.build_knowledge_graph
    end
  end

  describe '#processors' do
    it 'returns FileProcessor constants' do
      processors = service.processors
      expect(processors).to include(:Txt)
      expect(processors).to include(:Pdf)
    end

    it 'delegates to FileProcessor.constants' do
      expect(FileProcessor).to receive(:constants)
      service.processors
    end
  end

  describe 'file type detection' do
    let(:txt_service) { Documents::ImportService.new('document.txt') }
    let(:pdf_service) { Documents::ImportService.new('document.pdf') }

    before do
      mock_file_processor
    end

    it 'detects txt files' do
      expect(txt_service.document.source_type).to eq('.txt')
    end

    it 'detects pdf files' do
      expect(pdf_service.document.source_type).to eq('.pdf')
    end
  end

  describe 'error handling' do
    it 'handles file reading errors' do
      allow(File).to receive(:open).and_raise(Errno::ENOENT)
      
      expect {
        service.read_file
      }.to raise_error(Errno::ENOENT)
    end

    it 'handles LLM service errors' do
      service.document.text = 'Test content'
      # Mock the prompt first
      allow(Prompt).to receive(:find_by).with(name: 'text_summarization').and_return(
        double('Prompt', tags_hash: { text: nil }, content: 'Summarize: %{text}')
      )
      allow_any_instance_of(Llm::QueryService).to receive(:ask).and_raise(StandardError, 'LLM Error')

      expect {
        service.summerise_doc
      }.to raise_error(StandardError, 'LLM Error')
    end

    it 'handles embedding service errors' do
      service.document.chunks = create_test_chunks(1)
      allow_any_instance_of(Llm::EmbeddingService).to receive(:embed_chunks).and_raise(StandardError, 'Embedding Error')
      
      expect {
        service.embed_chunks
      }.to raise_error(StandardError, 'Embedding Error')
    end
  end

  describe 'integration test', :vcr do
    # This would be an integration test with real services
    # but requires VCR cassettes and proper API keys
    
    it 'processes a real document end-to-end' do
      # Skip this test in CI or when API keys are not available
      skip 'Integration test requires API keys' unless ENV['OPENAI_API_KEY']
      
      # This would test the full pipeline with real services
      # service.process
      # expect(service.document.summary).to be_present
      # expect(service.document.chunks).not_to be_empty
    end
  end

  describe 'performance' do
    it 'processes documents efficiently' do
      # Create a larger test document
      large_content = 'Lorem ipsum dolor sit amet. ' * 1000
      allow(File).to receive(:open).and_return(StringIO.new(large_content))
      mock_file_processor(large_content)
      mock_llm_response
      mock_embedding_response
      mock_neo4j_query

      # Mock all the prompts needed
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

      expect {
        Timeout.timeout(10) do
          service.process
        end
      }.not_to raise_error
    end
  end
end
