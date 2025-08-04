# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Current, type: :model do
  describe 'inheritance' do
    it 'inherits from ActiveSupport::CurrentAttributes' do
      expect(Current.superclass).to eq(ActiveSupport::CurrentAttributes)
    end
  end

  describe 'attributes' do
    it 'has ailog_session attribute' do
      expect(Current).to respond_to(:ailog_session)
      expect(Current).to respond_to(:ailog_session=)
    end
  end

  describe 'attribute functionality' do
    after do
      # Clean up current attributes after each test
      Current.reset
    end

    it 'can set and get ailog_session' do
      session_uuid = SecureRandom.uuid
      Current.ailog_session = session_uuid
      expect(Current.ailog_session).to eq(session_uuid)
    end

    it 'starts with nil ailog_session' do
      expect(Current.ailog_session).to be_nil
    end

    it 'can reset ailog_session to nil' do
      Current.ailog_session = SecureRandom.uuid
      Current.ailog_session = nil
      expect(Current.ailog_session).to be_nil
    end

    it 'persists across method calls within same thread' do
      session_uuid = SecureRandom.uuid
      Current.ailog_session = session_uuid
      
      # Simulate method call that uses Current.ailog_session
      def test_method
        Current.ailog_session
      end
      
      expect(test_method).to eq(session_uuid)
    end

    it 'resets between requests' do
      session_uuid = SecureRandom.uuid
      Current.ailog_session = session_uuid
      
      Current.reset
      
      expect(Current.ailog_session).to be_nil
    end
  end

  describe 'thread safety' do
    it 'maintains separate values per thread' do
      main_session = SecureRandom.uuid
      thread_session = SecureRandom.uuid
      
      Current.ailog_session = main_session
      
      thread_result = nil
      thread = Thread.new do
        Current.ailog_session = thread_session
        thread_result = Current.ailog_session
      end
      
      thread.join
      
      expect(Current.ailog_session).to eq(main_session)
      expect(thread_result).to eq(thread_session)
    end
  end

  describe 'usage in services' do
    it 'can be used to track session across service calls' do
      session_uuid = SecureRandom.uuid
      Current.ailog_session = session_uuid
      
      # Simulate how it's used in Documents::ImportService
      expect(Current.ailog_session).to eq(session_uuid)
      
      # Simulate clearing session
      Current.ailog_session = nil
      expect(Current.ailog_session).to be_nil
    end
  end
end
