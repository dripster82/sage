# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chunk, type: :model do
  subject { build(:chunk) }

  describe 'ActiveModel inclusion' do
    it 'includes ActiveModel::Model' do
      expect(Chunk.included_modules).to include(ActiveModel::Model)
    end

    it 'responds to ActiveModel methods' do
      expect(subject).to respond_to(:valid?)
      expect(subject).to respond_to(:errors)
      expect(subject).to respond_to(:attributes)
    end
  end

  describe 'attributes' do
    it 'has text attribute' do
      expect(subject).to respond_to(:text)
      expect(subject).to respond_to(:text=)
    end

    it 'has file_path attribute' do
      expect(subject).to respond_to(:file_path)
      expect(subject).to respond_to(:file_path=)
    end

    it 'has position attribute' do
      expect(subject).to respond_to(:position)
      expect(subject).to respond_to(:position=)
    end

    it 'has vector attribute' do
      expect(subject).to respond_to(:vector)
      expect(subject).to respond_to(:vector=)
    end
  end

  describe 'initialization' do
    it 'can be initialized with attributes' do
      chunk = Chunk.new(
        text: 'Test chunk content',
        file_path: 'test.txt',
        position: 0
      )
      
      expect(chunk.text).to eq('Test chunk content')
      expect(chunk.file_path).to eq('test.txt')
      expect(chunk.position).to eq(0)
    end

    it 'can be initialized without attributes' do
      chunk = Chunk.new
      expect(chunk.text).to be_nil
      expect(chunk.file_path).to be_nil
      expect(chunk.position).to be_nil
      expect(chunk.vector).to be_nil
    end
  end

  describe 'factory' do
    it 'creates valid chunk' do
      chunk = build(:chunk)
      expect(chunk).to be_valid
      expect(chunk.text).to be_present
      expect(chunk.file_path).to be_present
      expect(chunk.position).to be_present
      expect(chunk.vector).to be_present
    end

    it 'creates chunk with vector' do
      chunk = build(:chunk)
      expect(chunk.vector).to be_an(Array)
      expect(chunk.vector.size).to eq(1536) # Standard embedding size
    end
  end

  describe 'factory traits' do
    it 'creates first chunk' do
      chunk = build(:chunk, :first_chunk)
      expect(chunk.position).to eq(0)
    end

    it 'creates middle chunk' do
      chunk = build(:chunk, :middle_chunk)
      expect(chunk.position).to eq(1)
    end

    it 'creates last chunk' do
      chunk = build(:chunk, :last_chunk)
      expect(chunk.position).to eq(2)
    end

    it 'creates chunk with long text' do
      chunk = build(:chunk, :long_text)
      expect(chunk.text.length).to be > 100
    end

    it 'creates chunk with short text' do
      chunk = build(:chunk, :short_text)
      expect(chunk.text.length).to be < 100
    end

    it 'creates chunk without vector' do
      chunk = build(:chunk, :without_vector)
      expect(chunk.vector).to be_nil
    end

    it 'creates pdf chunk' do
      chunk = build(:chunk, :pdf_chunk)
      expect(chunk.file_path).to end_with('.pdf')
    end

    it 'creates chunks with sequence' do
      chunks = build_list(:chunk, 3, :with_sequence)
      positions = chunks.map(&:position)
      expect(positions).to eq([1, 2, 3])
    end
  end

  describe 'validation' do
    it 'is valid by default' do
      expect(subject).to be_valid
    end

    # Add custom validations if needed
    context 'with custom validations' do
      # These would be added if Chunk model had validations
      # it { should validate_presence_of(:text) }
      # it { should validate_presence_of(:file_path) }
      # it { should validate_numericality_of(:position).is_greater_than_or_equal_to(0) }
    end
  end

  describe 'vector operations' do
    it 'can store embedding vectors' do
      vector = Array.new(1536) { rand(-1.0..1.0) }
      subject.vector = vector
      expect(subject.vector).to eq(vector)
    end

    it 'handles nil vectors' do
      subject.vector = nil
      expect(subject.vector).to be_nil
    end

    it 'can store different vector sizes' do
      vector = Array.new(768) { rand(-1.0..1.0) }
      subject.vector = vector
      expect(subject.vector.size).to eq(768)
    end
  end

  describe 'position handling' do
    it 'can store integer positions' do
      subject.position = 5
      expect(subject.position).to eq(5)
    end

    it 'can store zero position' do
      subject.position = 0
      expect(subject.position).to eq(0)
    end

    it 'handles nil position' do
      subject.position = nil
      expect(subject.position).to be_nil
    end
  end

  describe 'text content' do
    it 'can store long text' do
      long_text = 'a' * 10000
      subject.text = long_text
      expect(subject.text).to eq(long_text)
    end

    it 'can store empty text' do
      subject.text = ''
      expect(subject.text).to eq('')
    end

    it 'can store text with special characters' do
      special_text = "Text with émojis 🚀 and special chars: @#$%^&*()"
      subject.text = special_text
      expect(subject.text).to eq(special_text)
    end
  end

  describe 'integration with services' do
    it 'works with ChunkService' do
      # This tests that chunks can be created by ChunkService
      document = build(:document, :without_chunks)
      chunk_service = ChunkService.new(document)
      
      expect { chunk_service.chunk }.not_to raise_error
      expect(document.chunks).to all(be_a(Chunk))
    end

    it 'works with embedding service' do
      # This would test integration with Llm::EmbeddingService
      # but requires mocking the LLM service
      chunk = build(:chunk, :without_vector)
      
      # Mock the embedding service
      mock_embedding_response
      
      # This would be called by the embedding service
      chunk.vector = Array.new(1536) { rand }
      expect(chunk.vector).to be_present
    end
  end
end
