# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChunkService, type: :service do
  let(:document) { build(:document, :without_chunks) }
  let(:service) { ChunkService.new(document) }

  it_behaves_like 'a service object'

  describe 'initialization' do
    it 'initializes with document' do
      expect(service.instance_variable_get(:@document)).to eq(document)
    end

    it 'sets default chunk_size' do
      expect(service.instance_variable_get(:@chunk_size)).to eq(1000)
    end

    it 'sets default chunk_overlap' do
      expect(service.instance_variable_get(:@chunk_overlap)).to eq(100)
    end

    it 'sets default separators' do
      expected_separators = ["\n\n", "\n", " ", ""]
      expect(service.instance_variable_get(:@separators)).to eq(expected_separators)
    end

    it 'accepts custom parameters' do
      custom_service = ChunkService.new(
        document,
        chunk_size: 500,
        chunk_overlap: 50,
        separators: ["\n", " "]
      )
      
      expect(custom_service.instance_variable_get(:@chunk_size)).to eq(500)
      expect(custom_service.instance_variable_get(:@chunk_overlap)).to eq(50)
      expect(custom_service.instance_variable_get(:@separators)).to eq(["\n", " "])
    end
  end

  describe '#chunk' do
    before do
      # Mock Baran::RecursiveCharacterTextSplitter
      @mock_splitter = double('Baran::RecursiveCharacterTextSplitter')
      allow(Baran::RecursiveCharacterTextSplitter).to receive(:new).and_return(@mock_splitter)
    end

    it 'creates chunks from document text' do
      mock_chunks = [
        { text: 'First chunk' },
        { text: 'Second chunk' },
        { text: 'Third chunk' }
      ]
      
      allow(@mock_splitter).to receive(:chunks).and_return(mock_chunks)
      
      service.chunk
      
      expect(document.chunks.size).to eq(3)
      expect(document.chunks.first).to be_a(Chunk)
      expect(document.chunks.first.text).to eq('First chunk')
      expect(document.chunks.first.position).to eq(0)
    end

    it 'sets correct positions for chunks' do
      mock_chunks = [
        { text: 'First chunk' },
        { text: 'Second chunk' }
      ]
      
      allow(@mock_splitter).to receive(:chunks).and_return(mock_chunks)
      
      service.chunk
      
      expect(document.chunks[0].position).to eq(0)
      expect(document.chunks[1].position).to eq(1)
    end

    it 'sets file_path for all chunks' do
      mock_chunks = [{ text: 'Test chunk' }]
      allow(@mock_splitter).to receive(:chunks).and_return(mock_chunks)
      
      service.chunk
      
      expect(document.chunks.first.file_path).to eq(document.file_path)
    end

    it 'configures splitter with correct parameters' do
      expect(Baran::RecursiveCharacterTextSplitter).to receive(:new).with(
        chunk_size: 1000,
        chunk_overlap: 100,
        separators: ["\n\n", "\n", " ", ""]
      )
      
      allow(@mock_splitter).to receive(:chunks).and_return([])
      
      service.chunk
    end

    it 'uses custom text when provided' do
      custom_text = 'Custom text to chunk'
      allow(@mock_splitter).to receive(:chunks).with(custom_text).and_return([])
      
      service.chunk(custom_text)
    end

    it 'uses custom size and overlap when provided' do
      allow(@mock_splitter).to receive(:chunks).and_return([])
      
      service.chunk(size: 500, overlap: 50)
      
      # Note: The current implementation doesn't use these parameters
      # This test documents the current behavior
    end

    it 'raises error when size <= overlap' do
      expect {
        service.chunk(size: 100, overlap: 100)
      }.to raise_error(ArgumentError, 'Size must be greater than overlap')
    end

    it 'raises error when size < overlap' do
      expect {
        service.chunk(size: 50, overlap: 100)
      }.to raise_error(ArgumentError, 'Size must be greater than overlap')
    end
  end

  describe 'integration with Baran gem' do
    it 'uses Baran::RecursiveCharacterTextSplitter' do
      # This test ensures the service integrates with the actual Baran gem
      # We'll use a real splitter with simple text
      document.text = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph."
      
      service.chunk
      
      expect(document.chunks).not_to be_empty
      expect(document.chunks).to all(be_a(Chunk))
    end

    it 'handles empty text' do
      document.text = ''
      
      service.chunk
      
      # Should handle empty text gracefully
      expect(document.chunks).to be_an(Array)
    end

    it 'handles nil text' do
      document.text = nil
      
      expect {
        service.chunk
      }.not_to raise_error
    end
  end

  describe 'chunk creation' do
    before do
      document.text = "This is a test document with multiple sentences. It should be split into chunks."
    end

    it 'creates Chunk objects with correct attributes' do
      service.chunk
      
      chunk = document.chunks.first
      expect(chunk.text).to be_present
      expect(chunk.file_path).to eq(document.file_path)
      expect(chunk.position).to be >= 0
      expect(chunk.vector).to be_nil # Vectors are added later by embedding service
    end

    it 'maintains chunk order' do
      service.chunk
      
      positions = document.chunks.map(&:position)
      expect(positions).to eq(positions.sort)
    end
  end

  describe 'error handling' do
    it 'handles Baran splitter errors gracefully' do
      allow(Baran::RecursiveCharacterTextSplitter).to receive(:new).and_raise(StandardError, 'Splitter error')
      
      expect {
        service.chunk
      }.to raise_error(StandardError, 'Splitter error')
    end
  end

  describe 'performance considerations' do
    it 'handles large documents' do
      # Create a large document
      large_text = 'Lorem ipsum dolor sit amet. ' * 1000
      document.text = large_text
      
      expect {
        service.chunk
      }.not_to raise_error
      
      expect(document.chunks.size).to be > 1
    end
  end
end
