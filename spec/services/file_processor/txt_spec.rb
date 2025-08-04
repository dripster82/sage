# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FileProcessor::Txt, type: :service do
  describe 'constants' do
    it 'defines supported extensions' do
      expect(FileProcessor::Txt::EXTENSIONS).to eq(['.txt'])
    end

    it 'defines supported content types' do
      expect(FileProcessor::Txt::CONTENT_TYPES).to eq(['text/plain'])
    end
  end

  describe '.parse' do
    let(:file_content) { 'This is a test text file content.' }
    let(:file_data) { StringIO.new(file_content) }

    it 'reads and returns file content' do
      result = FileProcessor::Txt.parse(file_data)
      expect(result).to eq(file_content)
    end

    it 'handles empty files' do
      empty_file = StringIO.new('')
      result = FileProcessor::Txt.parse(empty_file)
      expect(result).to eq('')
    end

    it 'handles files with newlines' do
      multiline_content = "Line 1\nLine 2\nLine 3"
      multiline_file = StringIO.new(multiline_content)
      result = FileProcessor::Txt.parse(multiline_file)
      expect(result).to eq(multiline_content)
    end

    it 'handles files with special characters' do
      special_content = "Text with émojis 🚀 and special chars: @#$%^&*()"
      special_file = StringIO.new(special_content)
      result = FileProcessor::Txt.parse(special_file)
      expect(result).to eq(special_content)
    end

    it 'handles large files' do
      large_content = 'Lorem ipsum dolor sit amet. ' * 10000
      large_file = StringIO.new(large_content)
      
      expect {
        result = FileProcessor::Txt.parse(large_file)
        expect(result).to eq(large_content)
      }.not_to raise_error
    end

    it 'handles UTF-8 encoded content' do
      utf8_content = "UTF-8 content: café, naïve, résumé"
      utf8_file = StringIO.new(utf8_content)
      result = FileProcessor::Txt.parse(utf8_file)
      expect(result).to eq(utf8_content)
    end
  end

  describe 'file integration' do
    let(:temp_file) { create_temp_file(content: 'Test file content for integration') }

    after do
      temp_file.close
      temp_file.unlink
    end

    it 'works with real File objects' do
      result = FileProcessor::Txt.parse(temp_file)
      expect(result).to eq('Test file content for integration')
    end

    it 'handles file reading errors' do
      # Create a file and then close it to simulate read error
      temp_file.close
      
      expect {
        FileProcessor::Txt.parse(temp_file)
      }.to raise_error(IOError)
    end
  end

  describe 'error handling' do
    it 'raises error for nil input' do
      expect {
        FileProcessor::Txt.parse(nil)
      }.to raise_error(NoMethodError)
    end

    it 'handles IO errors gracefully' do
      bad_io = double('BadIO')
      allow(bad_io).to receive(:read).and_raise(IOError, 'Read failed')
      
      expect {
        FileProcessor::Txt.parse(bad_io)
      }.to raise_error(IOError, 'Read failed')
    end
  end

  describe 'compatibility with Documents::ImportService' do
    it 'is detected by import service for .txt files' do
      document = build(:document, file_path: 'test.txt')
      
      # Mock the content type detection
      allow(MIME::Types).to receive(:type_for).with('test.txt').and_return([
        double(content_type: 'text/plain')
      ])
      
      import_service = Documents::ImportService.new(document.file_path)
      processors = import_service.processors
      
      # Check that Txt processor is available
      expect(processors).to include(:Txt)
      
      # Check that it matches the file type
      txt_extensions = FileProcessor::Txt::EXTENSIONS
      txt_content_types = FileProcessor::Txt::CONTENT_TYPES
      
      expect(txt_extensions).to include(document.source_type)
      expect(txt_content_types).to include(document.content_type)
    end
  end

  describe 'performance' do
    it 'processes files efficiently' do
      # Test with a reasonably large file
      large_content = ('A' * 1000 + "\n") * 1000  # ~1MB file
      large_file = StringIO.new(large_content)
      
      expect {
        Timeout.timeout(5) do
          result = FileProcessor::Txt.parse(large_file)
          expect(result.length).to eq(large_content.length)
        end
      }.not_to raise_error
    end
  end

  describe 'memory usage' do
    it 'does not leak memory with large files' do
      # This is a basic test - in production you might want more sophisticated memory testing
      initial_memory = GC.stat[:total_allocated_objects]
      
      large_content = 'Content ' * 100000
      large_file = StringIO.new(large_content)
      
      FileProcessor::Txt.parse(large_file)
      
      GC.start
      final_memory = GC.stat[:total_allocated_objects]
      
      # Memory should not grow excessively
      expect(final_memory - initial_memory).to be < 1000000
    end
  end

  describe 'encoding handling' do
    it 'preserves original encoding' do
      content = "Test content"
      file = StringIO.new(content)
      
      result = FileProcessor::Txt.parse(file)
      expect(result.encoding).to eq(content.encoding)
    end

    it 'handles different encodings' do
      # Test with ASCII content
      ascii_content = "ASCII content"
      ascii_file = StringIO.new(ascii_content)
      
      result = FileProcessor::Txt.parse(ascii_file)
      expect(result).to eq(ascii_content)
    end
  end
end
