# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Application Routes', type: :request do
  # Test data
  let(:health_check_path) { '/up' }
  let(:root_path) { '/' }
  let(:admin_path) { '/admin' }
  let(:nonexistent_path) { '/nonexistent-route' }
  let(:expected_success_status) { 200 }
  let(:expected_redirect_status) { 301 } # Rails uses 301 for permanent redirects
  let(:expected_auth_redirect_status) { 302 } # Authentication redirects use 302
  let(:expected_not_found_status) { 404 }

  describe 'health check endpoint' do
    it 'returns successful response' do
      get health_check_path, headers: { 'Host' => 'localhost' }
      expect(response).to have_http_status(expected_success_status)
    end

    it 'indicates application is healthy' do
      get health_check_path, headers: { 'Host' => 'localhost' }
      expect(response.body).to include('html') # Health check returns simple HTML
    end
  end

  describe 'root path' do
    it 'redirects to admin' do
      get root_path, headers: { 'Host' => 'localhost' }
      expect(response).to have_http_status(expected_redirect_status)
      expect(response).to redirect_to(admin_path)
    end
  end

  describe 'admin routes' do
    context 'when not authenticated' do
      it 'redirects to login' do
        get admin_path, headers: { 'Host' => 'localhost' }
        expect(response).to have_http_status(expected_auth_redirect_status)
      end
    end

    context 'when authenticated' do
      let(:admin_user) { create(:admin_user) }

      before { sign_in admin_user }

      it 'allows access to admin panel' do
        get admin_path, headers: { 'Host' => 'localhost' }
        expect(response).to have_http_status(expected_success_status)
      end
    end
  end

  describe 'basic functionality' do
    it 'serves HTML content' do
      get health_check_path, headers: { 'Host' => 'localhost' }
      expect(response.content_type).to include('text/html')
    end

    it 'responds within reasonable time' do
      start_time = Time.now
      get health_check_path, headers: { 'Host' => 'localhost' }
      end_time = Time.now

      expect(response).to have_http_status(expected_success_status)
      expect(end_time - start_time).to be < 2.0
    end

    it 'handles basic routing correctly' do
      get root_path, headers: { 'Host' => 'localhost' }
      expect(response).to have_http_status(expected_redirect_status)
    end
  end

  describe 'security headers' do
    describe 'content security policy configuration' do
      # Note: In test environment, CSP headers may not be fully applied
      # These tests verify the CSP configuration is properly set up

      it 'has CSP configured at application level' do
        expect(Rails.application.config.content_security_policy).to be_present
        expect(Rails.application.config.content_security_policy_report_only).to be true
      end

      it 'CSP policy contains expected directives' do
        policy = Rails.application.config.content_security_policy
        policy_string = policy.build(ActionDispatch::Request.new({}))

        # Test each directive from the configuration
        expect(policy_string).to include("default-src 'self' https:")
        expect(policy_string).to include("font-src 'self' https: data:")
        expect(policy_string).to include("img-src 'self' https: data:")
        expect(policy_string).to include("object-src 'none'")
        expect(policy_string).to include("script-src 'self' https:")
        expect(policy_string).to include("style-src 'self' https:")
      end

      it 'nonce generator is configured correctly' do
        nonce_generator = Rails.application.config.content_security_policy_nonce_generator
        expect(nonce_generator).to be_present

        # Test nonce generation
        mock_request = double('Request', session: double('Session', id: 'test-session'))
        nonce = nonce_generator.call(mock_request)
        expect(nonce).to eq('test-session')
      end

      it 'nonce directives are configured for script and style sources' do
        nonce_directives = Rails.application.config.content_security_policy_nonce_directives
        expect(nonce_directives).to include('script-src')
        expect(nonce_directives).to include('style-src')
      end

      context 'security considerations' do
        let(:policy_string) { Rails.application.config.content_security_policy.build(ActionDispatch::Request.new({})) }

        it 'blocks object-src completely for security' do
          expect(policy_string).to include("object-src 'none'")
        end

        it 'allows HTTPS sources for resource loading' do
          expect(policy_string).to include('https:')
        end

        it 'allows data URIs only for fonts and images' do
          expect(policy_string).to match(/font-src[^;]*data:/)
          expect(policy_string).to match(/img-src[^;]*data:/)
          expect(policy_string).not_to match(/script-src[^;]*data:/)
          expect(policy_string).not_to match(/style-src[^;]*data:/)
        end

        it 'is configured in report-only mode for gradual implementation' do
          expect(Rails.application.config.content_security_policy_report_only).to be true
        end
      end
    end
  end
end
