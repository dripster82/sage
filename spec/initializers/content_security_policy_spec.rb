# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Content Security Policy Configuration', type: :initializer do
  describe 'CSP configuration' do
    it 'configures content security policy' do
      expect(Rails.application.config.content_security_policy).to be_present
    end

    it 'sets report-only mode to true' do
      expect(Rails.application.config.content_security_policy_report_only).to be true
    end

    it 'configures nonce generator' do
      expect(Rails.application.config.content_security_policy_nonce_generator).to be_present
      expect(Rails.application.config.content_security_policy_nonce_generator).to be_a(Proc)
    end

    it 'configures nonce directives for script-src and style-src' do
      expected_directives = %w(script-src style-src)
      expect(Rails.application.config.content_security_policy_nonce_directives).to eq(expected_directives)
    end
  end

  describe 'CSP policy directives' do
    let(:policy) { Rails.application.config.content_security_policy }
    let(:policy_string) { policy.build(ActionDispatch::Request.new({})) }

    it 'configures default-src directive' do
      expect(policy_string).to include("default-src 'self' https:")
    end

    it 'configures font-src directive' do
      expect(policy_string).to include("font-src 'self' https: data:")
    end

    it 'configures img-src directive' do
      expect(policy_string).to include("img-src 'self' https: data:")
    end

    it 'configures object-src directive to none' do
      expect(policy_string).to include("object-src 'none'")
    end

    it 'configures script-src directive' do
      expect(policy_string).to include("script-src 'self' https:")
    end

    it 'configures style-src directive' do
      expect(policy_string).to include("style-src 'self' https:")
    end

    it 'does not configure report-uri by default' do
      expect(policy_string).not_to include('report-uri')
    end
  end

  describe 'nonce generation' do
    let(:nonce_generator) { Rails.application.config.content_security_policy_nonce_generator }
    let(:mock_request) { double('Request', session: double('Session', id: 'test-session-id')) }

    it 'generates nonce based on session ID' do
      nonce = nonce_generator.call(mock_request)
      expect(nonce).to eq('test-session-id')
    end

    it 'handles different session IDs' do
      request1 = double('Request', session: double('Session', id: 'session-1'))
      request2 = double('Request', session: double('Session', id: 'session-2'))

      nonce1 = nonce_generator.call(request1)
      nonce2 = nonce_generator.call(request2)

      expect(nonce1).to eq('session-1')
      expect(nonce2).to eq('session-2')
      expect(nonce1).not_to eq(nonce2)
    end

    it 'converts session ID to string' do
      numeric_session = double('Request', session: double('Session', id: 12345))
      nonce = nonce_generator.call(numeric_session)
      expect(nonce).to eq('12345')
      expect(nonce).to be_a(String)
    end
  end

  describe 'CSP policy building with nonces' do
    # Note: Nonces are only added during actual HTTP requests through middleware
    # These tests verify the nonce generation mechanism works correctly

    it 'nonce generator is properly configured' do
      nonce_generator = Rails.application.config.content_security_policy_nonce_generator
      mock_request = double('Request', session: double('Session', id: 'test-session'))

      nonce = nonce_generator.call(mock_request)
      expect(nonce).to eq('test-session')
    end

    it 'nonce directives are configured for script-src and style-src' do
      nonce_directives = Rails.application.config.content_security_policy_nonce_directives
      expect(nonce_directives).to include('script-src')
      expect(nonce_directives).to include('style-src')
    end

    it 'policy can be built with different request contexts' do
      policy = Rails.application.config.content_security_policy

      # Test with different mock requests
      request1 = double('Request', session: double('Session', id: 'session-1'))
      request2 = double('Request', session: double('Session', id: 'session-2'))

      policy1 = policy.build(request1)
      policy2 = policy.build(request2)

      # Both should contain the base policy
      expect(policy1).to include("script-src 'self' https:")
      expect(policy2).to include("style-src 'self' https:")

      # They should be identical since nonces are added by middleware, not here
      expect(policy1).to eq(policy2)
    end
  end

  describe 'security considerations' do
    let(:policy_string) { Rails.application.config.content_security_policy.build(ActionDispatch::Request.new({})) }

    it 'blocks object-src completely' do
      expect(policy_string).to include("object-src 'none'")
    end

    it 'allows HTTPS sources for all resource types' do
      %w[default-src font-src img-src script-src style-src].each do |directive|
        expect(policy_string).to include("#{directive}"), "#{directive} should be present"
        expect(policy_string).to match(/#{directive}[^;]*https:/), "#{directive} should allow HTTPS sources"
      end
    end

    it 'allows self for all resource types except object-src' do
      %w[default-src font-src img-src script-src style-src].each do |directive|
        expect(policy_string).to match(/#{directive}[^;]*'self'/), "#{directive} should allow 'self'"
      end
    end

    it 'allows data URIs for fonts and images only' do
      expect(policy_string).to match(/font-src[^;]*data:/)
      expect(policy_string).to match(/img-src[^;]*data:/)

      # Should not allow data URIs for scripts or styles
      expect(policy_string).not_to match(/script-src[^;]*data:/)
      expect(policy_string).not_to match(/style-src[^;]*data:/)
    end
  end

  describe 'report-only mode implications' do
    it 'is configured for monitoring without blocking' do
      expect(Rails.application.config.content_security_policy_report_only).to be true
    end

    it 'allows gradual CSP implementation' do
      # Report-only mode means violations are reported but not blocked
      # This is useful for testing CSP policies before enforcing them
      expect(Rails.application.config.content_security_policy_report_only).to be true
    end
  end
end
