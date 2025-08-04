# frozen_string_literal: true

require 'rails_helper'
require 'pdf-reader'

RSpec.describe FileProcessor::Pdf, type: :service do
  describe 'constants' do
    it 'defines supported extensions' do
      expect(FileProcessor::Pdf::EXTENSIONS).to eq(['.pdf'])
    end

    it 'defines supported content types' do
      expect(FileProcessor::Pdf::CONTENT_TYPES).to eq(['application/pdf'])
    end
  end

  describe '.parse' do
    let(:mock_pdf_reader) { double('PDF::Reader') }
    let(:mock_page1) { double('Page1', text: 'First page content') }
    let(:mock_page2) { double('Page2', text: 'Second page content') }
    let(:mock_pages) { [mock_page1, mock_page2] }
    let(:pdf_data) { StringIO.new('fake pdf data') }

    before do
      allow(PDF::Reader).to receive(:new).and_return(mock_pdf_reader)
      allow(mock_pdf_reader).to receive(:pages).and_return(mock_pages)
    end

    it 'extracts text from PDF pages' do
      result = described_class.parse(pdf_data)
      expect(result).to eq("First page content\n\nSecond page content")
    end

    it 'creates PDF::Reader with StringIO from file data' do
      expect(PDF::Reader).to receive(:new).with(kind_of(StringIO))
      described_class.parse(pdf_data)
    end

    it 'reads file data into StringIO' do
      expect(pdf_data).to receive(:read).and_return('pdf content')
      described_class.parse(pdf_data)
    end

    it 'joins pages with double newlines' do
      result = described_class.parse(pdf_data)
      expect(result).to include("\n\n")
    end

    it 'handles single page PDFs' do
      allow(mock_pdf_reader).to receive(:pages).and_return([mock_page1])

      result = described_class.parse(pdf_data)
      expect(result).to eq('First page content')
    end

    it 'handles empty PDFs' do
      allow(mock_pdf_reader).to receive(:pages).and_return([])

      result = described_class.parse(pdf_data)
      expect(result).to eq('')
    end

    it 'handles pages with empty text' do
      empty_page = double('EmptyPage', text: '')
      allow(mock_pdf_reader).to receive(:pages).and_return([empty_page, mock_page1])

      result = described_class.parse(pdf_data)
      expect(result).to eq("\n\nFirst page content")
    end

    it 'handles pages with nil text' do
      nil_page = double('NilPage', text: nil)
      allow(mock_pdf_reader).to receive(:pages).and_return([nil_page, mock_page1])

      result = described_class.parse(pdf_data)
      expect(result).to eq("\n\nFirst page content")
    end
  end

  describe 'error handling' do
    let(:pdf_data) { StringIO.new('invalid pdf data') }

    it 'handles PDF parsing errors' do
      allow(PDF::Reader).to receive(:new).and_raise(PDF::Reader::MalformedPDFError)

      expect {
        described_class.parse(pdf_data)
      }.to raise_error(PDF::Reader::MalformedPDFError)
    end

    it 'handles file reading errors' do
      allow(pdf_data).to receive(:read).and_raise(IOError, 'Read failed')

      expect {
        described_class.parse(pdf_data)
      }.to raise_error(IOError, 'Read failed')
    end

    it 'handles nil input' do
      expect {
        described_class.parse(nil)
      }.to raise_error(NoMethodError)
    end

    it 'handles corrupted PDF files' do
      allow(PDF::Reader).to receive(:new).and_raise(PDF::Reader::UnsupportedFeatureError)

      expect {
        described_class.parse(pdf_data)
      }.to raise_error(PDF::Reader::UnsupportedFeatureError)
    end
  end

  describe 'integration with PDF::Reader gem' do
    # These tests would require actual PDF files or more sophisticated mocking

    it 'uses PDF::Reader correctly' do
      pdf_data = StringIO.new('fake pdf')

      expect(PDF::Reader).to receive(:new).with(kind_of(StringIO))

      # Mock the chain of calls
      reader = double('Reader')
      pages = double('Pages')
      allow(PDF::Reader).to receive(:new).and_return(reader)
      allow(reader).to receive(:pages).and_return(pages)
      allow(pages).to receive(:map).and_return(['page1', 'page2'])

      described_class.parse(pdf_data)
    end
  end

  describe 'compatibility with Documents::ImportService' do
    it 'is detected by import service for .pdf files' do
      document = build(:document, file_path: 'test.pdf')
      
      # Mock the content type detection
      allow(MIME::Types).to receive(:type_for).with('test.pdf').and_return([
        double(content_type: 'application/pdf')
      ])
      
      import_service = Documents::ImportService.new(document.file_path)
      processors = import_service.processors
      
      # Check that Pdf processor is available
      expect(processors).to include(:Pdf)
      
      # Check that it matches the file type
      pdf_extensions = FileProcessor::Pdf::EXTENSIONS
      pdf_content_types = FileProcessor::Pdf::CONTENT_TYPES
      
      expect(pdf_extensions).to include(document.source_type)
      expect(pdf_content_types).to include(document.content_type)
    end
  end

  describe 'text extraction quality' do
    let(:mock_pdf_reader) { double('PDF::Reader') }
    let(:pdf_data) { StringIO.new('fake pdf data') }

    before do
      allow(PDF::Reader).to receive(:new).and_return(mock_pdf_reader)
    end

    it 'preserves text formatting' do
      formatted_page = double('Page', text: "Title\n\nParagraph 1\n\nParagraph 2")
      allow(mock_pdf_reader).to receive(:pages).and_return([formatted_page])

      result = described_class.parse(pdf_data)
      expect(result).to eq("Title\n\nParagraph 1\n\nParagraph 2")
    end

    it 'handles special characters in PDF text' do
      special_page = double('Page', text: "Text with émojis 🚀 and symbols: ©®™")
      allow(mock_pdf_reader).to receive(:pages).and_return([special_page])

      result = described_class.parse(pdf_data)
      expect(result).to eq("Text with émojis 🚀 and symbols: ©®™")
    end

    it 'handles large amounts of text' do
      large_text = 'Lorem ipsum dolor sit amet. ' * 1000
      large_page = double('Page', text: large_text)
      allow(mock_pdf_reader).to receive(:pages).and_return([large_page])

      result = described_class.parse(pdf_data)
      expect(result).to eq(large_text)
    end
  end

  describe 'performance' do
    let(:mock_pdf_reader) { double('PDF::Reader') }
    let(:pdf_data) { StringIO.new('fake pdf data') }

    before do
      allow(PDF::Reader).to receive(:new).and_return(mock_pdf_reader)
    end

    it 'processes multi-page PDFs efficiently' do
      # Simulate a large PDF with many pages
      pages = (1..100).map do |i|
        double("Page#{i}", text: "Content of page #{i}")
      end
      allow(mock_pdf_reader).to receive(:pages).and_return(pages)
      
      expect {
        Timeout.timeout(5) do
          result = described_class.parse(pdf_data)
          expect(result).to include('Content of page 1')
          expect(result).to include('Content of page 100')
        end
      }.not_to raise_error
    end
  end

  describe 'memory management' do
    let(:mock_pdf_reader) { double('PDF::Reader') }
    let(:pdf_data) { StringIO.new('fake pdf data') }

    before do
      allow(PDF::Reader).to receive(:new).and_return(mock_pdf_reader)
    end

    it 'does not leak memory with large PDFs' do
      # Create many pages with substantial content
      pages = (1..50).map do |i|
        double("Page#{i}", text: 'Large content ' * 1000)
      end
      allow(mock_pdf_reader).to receive(:pages).and_return(pages)
      
      initial_memory = GC.stat[:total_allocated_objects]

      described_class.parse(pdf_data)

      GC.start
      final_memory = GC.stat[:total_allocated_objects]
      
      # Memory should not grow excessively
      expect(final_memory - initial_memory).to be < 10000000
    end
  end

  describe 'file type validation' do
    it 'works with actual PDF file extensions' do
      expect(FileProcessor::Pdf::EXTENSIONS).to include('.pdf')
    end

    it 'works with actual PDF content types' do
      expect(FileProcessor::Pdf::CONTENT_TYPES).to include('application/pdf')
    end
  end
end
