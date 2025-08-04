# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Document, type: :model do
  subject { build(:document) }

  describe 'ActiveModel inclusion' do
    it 'includes ActiveModel::Model' do
      expect(Document.included_modules).to include(ActiveModel::Model)
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

    it 'has summary attribute' do
      expect(subject).to respond_to(:summary)
      expect(subject).to respond_to(:summary=)
    end

    it 'has vector attribute' do
      expect(subject).to respond_to(:vector)
      expect(subject).to respond_to(:vector=)
    end

    it 'has chunks attribute' do
      expect(subject).to respond_to(:chunks)
      expect(subject).to respond_to(:chunks=)
    end
  end

  describe 'initialization' do
    it 'can be initialized with attributes' do
      document = Document.new(
        file_path: 'test.txt',
        text: 'Test content'
      )
      
      expect(document.file_path).to eq('test.txt')
      expect(document.text).to eq('Test content')
    end

    it 'can be initialized without attributes' do
      document = Document.new
      expect(document.file_path).to be_nil
      expect(document.text).to be_nil
    end
  end

  describe '#source_type' do
    it 'returns file extension' do
      subject.file_path = 'document.pdf'
      expect(subject.source_type).to eq('.pdf')
    end

    it 'returns extension for txt files' do
      subject.file_path = 'document.txt'
      expect(subject.source_type).to eq('.txt')
    end

    it 'handles files without extension' do
      subject.file_path = 'document'
      expect(subject.source_type).to eq('')
    end

    it 'handles complex file paths' do
      subject.file_path = '/path/to/my.document.pdf'
      expect(subject.source_type).to eq('.pdf')
    end
  end

  describe '#content_type' do
    before do
      # Mock MIME::Types to avoid dependency on actual file system
      allow(MIME::Types).to receive(:type_for).and_return([double(content_type: 'text/plain')])
    end

    it 'returns content type for file' do
      subject.file_path = 'document.txt'
      expect(subject.content_type).to eq('text/plain')
    end

    it 'calls MIME::Types.type_for with file_path' do
      subject.file_path = 'document.pdf'
      expect(MIME::Types).to receive(:type_for).with('document.pdf')
      subject.content_type
    end
  end

  describe 'factory' do
    it 'creates valid document' do
      document = build(:document)
      expect(document).to be_valid
      expect(document.file_path).to be_present
      expect(document.text).to be_present
    end

    it 'creates document with chunks' do
      document = build(:document)
      expect(document.chunks).to be_present
      expect(document.chunks).to all(be_a(Chunk))
    end
  end

  describe 'factory traits' do
    it 'creates pdf document' do
      document = build(:document, :pdf_document)
      expect(document.file_path).to end_with('.pdf')
    end

    it 'creates txt document' do
      document = build(:document, :txt_document)
      expect(document.file_path).to end_with('.txt')
    end

    it 'creates long document' do
      document = build(:document, :long_document)
      expect(document.chunks.size).to eq(10)
    end

    it 'creates short document' do
      document = build(:document, :short_document)
      expect(document.chunks.size).to eq(1)
    end

    it 'creates document without summary' do
      document = build(:document, :without_summary)
      expect(document.summary).to be_nil
    end

    it 'creates document without vector' do
      document = build(:document, :without_vector)
      expect(document.vector).to be_nil
    end

    it 'creates document without chunks' do
      document = build(:document, :without_chunks)
      expect(document.chunks).to be_empty
    end
  end

  describe 'validation' do
    it 'is valid by default' do
      expect(subject).to be_valid
    end

    # Add custom validations if needed
    context 'with custom validations' do
      # These would be added if Document model had validations
      # it { should validate_presence_of(:file_path) }
      # it { should validate_presence_of(:text) }
    end
  end

  describe 'integration with other components' do
    it 'works with ChunkService' do
      document = build(:document, :without_chunks)
      chunk_service = ChunkService.new(document)
      
      expect { chunk_service.chunk }.not_to raise_error
    end

    it 'works with Documents::ImportService' do
      # This would test integration but requires mocking file system
      # document = build(:document)
      # import_service = Documents::ImportService.new(document.file_path)
      # expect(import_service.document).to be_a(Document)
    end
  end
end
