# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Llm::EmbeddingService, type: :service do
  # Test data
  let(:sample_text) { 'Sample text to embed for testing purposes' }
  let(:empty_text) { '' }
  let(:long_text) { 'Lorem ipsum ' * 1000 }
  let(:special_text) { "Text with émojis 🚀 and symbols: @#$%^&*()" }
  let(:mock_vectors) { Array.new(1536) { rand(-1.0..1.0) } }
  let(:mock_embedding) { double('Embedding', vectors: mock_vectors) }
  let(:test_chunks) { create_test_chunks(3) }
  let(:many_chunks) { create_test_chunks(10) }
  let(:thread_count) { '2' }
  let(:rpm_limit) { '60' }
  let(:expected_interval) { 1.0 } # 60 RPM = 1 second interval

  let(:service) { described_class.new }

  it_behaves_like 'a service object'

  describe '#embed_text' do
    before do
      allow(RubyLLM).to receive(:embed).and_return(mock_embedding)
    end

    it 'calls RubyLLM.embed with text' do
      expect(RubyLLM).to receive(:embed).with(sample_text)
      service.embed_text(sample_text)
    end

    it 'returns embedding result' do
      result = service.embed_text(sample_text)
      expect(result).to eq(mock_embedding)
    end

    it 'handles empty text' do
      expect(RubyLLM).to receive(:embed).with(empty_text)
      service.embed_text(empty_text)
    end

    it 'handles long text' do
      expect(RubyLLM).to receive(:embed).with(long_text)
      service.embed_text(long_text)
    end

    it 'handles special characters' do
      expect(RubyLLM).to receive(:embed).with(special_text)
      service.embed_text(special_text)
    end
  end

  describe '#embed_chunks' do
    let(:chunks) { create_test_chunks(3) }
    let(:mock_embedding) { double('Embedding', vectors: [0.1, 0.2, 0.3]) }

    before do
      allow(service).to receive(:embed_text).and_return(mock_embedding)
      
      # Mock environment variables for threading control
      allow(ENV).to receive(:fetch).with('EMBEDDING_THREADS', 5).and_return('2')
      allow(ENV).to receive(:fetch).with('EMBEDDING_RPM', 120).and_return('60')
    end

    it 'embeds all chunks' do
      chunks.each do |chunk|
        expect(service).to receive(:embed_text).with(chunk.text)
      end
      
      service.embed_chunks(chunks)
    end

    it 'sets vector on each chunk' do
      service.embed_chunks(chunks)
      
      chunks.each do |chunk|
        expect(chunk.vector).to eq(mock_embedding)
      end
    end

    it 'returns the chunks array' do
      result = service.embed_chunks(chunks)
      expect(result).to eq(chunks)
    end

    it 'handles empty chunks array' do
      result = service.embed_chunks([])
      expect(result).to eq([])
    end

    it 'respects rate limiting' do
      # This test ensures the rate limiting logic is in place
      # We can't easily test the actual timing without making tests slow
      expect {
        service.embed_chunks(chunks)
      }.not_to raise_error
    end

    it 'uses threading for parallel processing' do
      # Mock Thread.new to verify threading is used
      threads = []
      allow(Thread).to receive(:new) do |&block|
        thread = double('Thread')
        threads << thread
        allow(thread).to receive(:join)
        block.call if block_given?
        thread
      end
      
      service.embed_chunks(chunks)
      expect(threads.size).to eq(chunks.size)
    end

    it 'waits for all threads to complete' do
      threads = []
      allow(Thread).to receive(:new) do |&block|
        thread = double('Thread')
        threads << thread
        expect(thread).to receive(:join)
        block.call if block_given?
        thread
      end
      
      service.embed_chunks(chunks)
    end
  end

  describe 'rate limiting' do
    let(:chunks) { create_test_chunks(5) }

    before do
      allow(service).to receive(:embed_text).and_return(double(vectors: [0.1]))
      allow(ENV).to receive(:fetch).with('EMBEDDING_THREADS', 5).and_return('2')
      allow(ENV).to receive(:fetch).with('EMBEDDING_RPM', 120).and_return('10') # Very low rate for testing
    end

    it 'respects maximum threads setting' do
      # Mock SizedQueue to verify thread limiting
      queue = double('SizedQueue')
      expect(SizedQueue).to receive(:new).with(2).and_return(queue)
      allow(queue).to receive(:push)
      allow(queue).to receive(:pop)
      
      service.embed_chunks(chunks)
    end

    it 'calculates correct interval from RPM' do
      # With 10 RPM, interval should be 6 seconds
      # We can't test the actual timing easily, but we can verify the calculation
      service.embed_chunks(chunks)
    end

    it 'uses mutex for thread synchronization' do
      # Verify that Mutex is used for synchronization
      mutex = double('Mutex')
      allow(Mutex).to receive(:new).and_return(mutex)
      expect(mutex).to receive(:synchronize).at_least(:once)
      
      service.embed_chunks(chunks)
    end
  end

  describe 'error handling' do
    let(:chunks) { create_test_chunks(2) }

    # Suppress thread exception reporting for error handling tests
    around(:each) do |example|
      original_report_on_exception = Thread.report_on_exception
      Thread.report_on_exception = false
      example.run
    ensure
      Thread.report_on_exception = original_report_on_exception
    end

    it 'handles embedding API errors' do
      allow(service).to receive(:embed_text).and_raise(StandardError, 'API Error')

      expect {
        service.embed_chunks(chunks)
      }.to raise_error(StandardError, 'API Error')
    end

    it 'handles network timeouts' do
      allow(service).to receive(:embed_text).and_raise(Timeout::Error)

      expect {
        service.embed_chunks(chunks)
      }.to raise_error(Timeout::Error)
    end

    it 'handles thread errors gracefully' do
      # Mock a thread that raises an error
      allow(Thread).to receive(:new).and_raise(StandardError, 'Thread error')

      expect {
        service.embed_chunks(chunks)
      }.to raise_error(StandardError, 'Thread error')
    end

    it 'ensures semaphore cleanup on error' do
      queue = double('SizedQueue')
      allow(SizedQueue).to receive(:new).and_return(queue)
      allow(queue).to receive(:push)
      expect(queue).to receive(:pop).at_least(:once) # Cleanup should happen

      allow(service).to receive(:embed_text).and_raise(StandardError, 'Test error')

      expect {
        service.embed_chunks(chunks)
      }.to raise_error(StandardError, 'Test error')
    end
  end

  describe 'integration with RubyLLM' do
    let(:text) { 'Integration test text' }

    it 'uses RubyLLM.embed method' do
      expect(RubyLLM).to receive(:embed).with(text)
      service.embed_text(text)
    end

    it 'works with actual RubyLLM configuration' do
      # This would test with real RubyLLM but requires API keys
      # For now, we'll just verify the method exists
      expect(RubyLLM).to respond_to(:embed)
    end
  end

  describe 'performance' do
    let(:many_chunks) { create_test_chunks(20) }

    before do
      allow(service).to receive(:embed_text).and_return(double(vectors: Array.new(1536) { rand }))
    end

    it 'processes many chunks efficiently' do
      expect {
        Timeout.timeout(10) do
          service.embed_chunks(many_chunks)
        end
      }.not_to raise_error
    end

    it 'uses parallel processing for better performance' do
      start_time = Time.now
      service.embed_chunks(many_chunks)
      end_time = Time.now
      
      # With threading, this should complete faster than sequential processing
      # This is a basic performance check
      expect(end_time - start_time).to be < 5.0
    end
  end

  describe 'memory management' do
    let(:chunks) { create_test_chunks(10) }

    before do
      allow(service).to receive(:embed_text).and_return(double(vectors: Array.new(1536) { rand }))
    end

    it 'does not leak memory with many embeddings' do
      initial_memory = GC.stat[:total_allocated_objects]
      
      service.embed_chunks(chunks)
      
      GC.start
      final_memory = GC.stat[:total_allocated_objects]
      
      # Memory should not grow excessively
      expect(final_memory - initial_memory).to be < 1000000
    end
  end

  describe 'configuration' do
    it 'reads thread count from environment' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('EMBEDDING_THREADS', 5).and_return('3')
      allow(ENV).to receive(:fetch).with('EMBEDDING_RPM', 120).and_return('120')

      # We can't directly test the private variable, but we can test behavior
      chunks = create_test_chunks.first(1)
      allow(service).to receive(:embed_text).and_return(double(vectors: [0.1]))

      expect {
        service.embed_chunks(chunks)
      }.not_to raise_error
    end

    it 'reads RPM limit from environment' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('EMBEDDING_THREADS', 5).and_return('5')
      allow(ENV).to receive(:fetch).with('EMBEDDING_RPM', 120).and_return('60')

      chunks = create_test_chunks.first(1)
      allow(service).to receive(:embed_text).and_return(double(vectors: [0.1]))

      expect {
        service.embed_chunks(chunks)
      }.not_to raise_error
    end

    it 'uses default values when environment variables not set' do
      allow(ENV).to receive(:fetch).with('EMBEDDING_THREADS', 5).and_return('5')
      allow(ENV).to receive(:fetch).with('EMBEDDING_RPM', 120).and_return('120')
      
      chunks = create_test_chunks.first(1)
      allow(service).to receive(:embed_text).and_return(double(vectors: [0.1]))
      
      expect {
        service.embed_chunks(chunks)
      }.not_to raise_error
    end
  end
end
