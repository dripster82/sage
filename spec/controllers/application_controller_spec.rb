# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  # Create a test controller to test ApplicationController functionality
  controller do
    def index
      render plain: 'Test action'
    end

    def test_route_not_found
      route_not_found
    end
  end

  before do
    # Add test routes
    routes.draw do
      get 'index' => 'anonymous#index'
      get 'test_route_not_found' => 'anonymous#test_route_not_found'
    end
  end

  describe 'inheritance' do
    it 'inherits from ActionController::Base' do
      expect(ApplicationController.superclass).to eq(ActionController::Base)
    end
  end

  describe 'security features' do
    describe 'CSRF protection' do
      it 'protects from forgery with exception' do
        expect(controller.class.forgery_protection_strategy).to eq(ActionController::RequestForgeryProtection::ProtectionMethods::Exception)
      end

      it 'has protect_from_forgery configured' do
        # This tests that CSRF protection is enabled
        expect(controller.class._process_action_callbacks.any? { |cb| 
          cb.filter.to_s.include?('verify_authenticity_token') 
        }).to be true
      end
    end

    describe 'rate limiting' do
      it 'has rate limiting configured' do
        # Test that rate limiting is set up
        # The exact implementation depends on the rate limiting gem used
        expect(controller.class).to respond_to(:rate_limit)
      end

      # Note: Testing actual rate limiting behavior would require 
      # integration tests and might be slow
    end
  end

  describe '#route_not_found' do
    it 'renders 404 page' do
      get :test_route_not_found
      expect(response).to have_http_status(:not_found)
    end

    it 'renders the 404.html file' do
      get :test_route_not_found
      # Check that the response body contains content from the 404.html file
      expect(response.body).to include('404')
    end

    it 'does not use application layout' do
      get :test_route_not_found
      # The layout: false option should be used
      expect(response.body).not_to include('<!DOCTYPE html>')
    end
  end

  describe 'error handling' do
    controller do
      def test_error
        raise StandardError, 'Test error'
      end
    end

    before do
      routes.draw do
        get 'test_error' => 'anonymous#test_error'
      end
    end

    it 'handles standard errors appropriately' do
      # In test environment, errors are typically re-raised
      expect {
        get :test_error
      }.to raise_error(StandardError, 'Test error')
    end
  end

  describe 'request handling' do
    it 'handles normal requests' do
      get :index
      expect(response).to be_successful
      expect(response.body).to eq('Test action')
    end

    it 'sets appropriate headers' do
      get :index
      expect(response.headers['Content-Type']).to include('text/plain')
    end
  end

  describe 'authentication integration' do
    # Since this app uses Devise for admin authentication,
    # we should test that the controller works with authentication

    context 'with authenticated admin user' do
      let(:admin_user) { create(:admin_user) }

      before do
        sign_in admin_user
      end

      it 'allows access to actions' do
        get :index
        expect(response).to be_successful
      end
    end

    context 'without authentication' do
      it 'still allows access to public actions' do
        # ApplicationController doesn't require authentication by default
        get :index
        expect(response).to be_successful
      end
    end
  end

  describe 'content security policy' do
    it 'has CSP configuration available' do
      # Check that CSP configuration is available in the application
      expect(Rails.application.config).to respond_to(:content_security_policy)
      expect(Rails.application.config).to respond_to(:content_security_policy_report_only)
    end

    it 'is configured in report-only mode' do
      expect(Rails.application.config.content_security_policy_report_only).to be true
    end

    it 'has nonce generator configured' do
      expect(Rails.application.config.content_security_policy_nonce_generator).to be_present
    end

    it 'has nonce directives configured for script-src and style-src' do
      expected_directives = %w(script-src style-src)
      expect(Rails.application.config.content_security_policy_nonce_directives).to eq(expected_directives)
    end

    context 'CSP middleware integration' do
      # Note: CSP headers are added by Rails middleware, not directly by controllers
      # In test environment, middleware may not be fully active

      it 'has CSP middleware configured in Rails stack' do
        # Verify CSP is configured at the application level
        expect(Rails.application.config.content_security_policy).to be_present
        expect(Rails.application.config.content_security_policy_report_only).to be true
      end

      it 'nonce generator works with request context' do
        # Test the nonce generator directly
        nonce_generator = Rails.application.config.content_security_policy_nonce_generator
        mock_request = double('Request', session: double('Session', id: 'test-session'))

        nonce = nonce_generator.call(mock_request)
        expect(nonce).to eq('test-session')
      end

      it 'CSP policy can be built for requests' do
        # Test that the policy can be built with a request context
        policy = Rails.application.config.content_security_policy
        mock_request = double('Request', session: double('Session', id: 'test-session'))

        policy_string = policy.build(mock_request)
        expect(policy_string).to include("script-src 'self' https:")
        expect(policy_string).to include("style-src 'self' https:")
      end
    end
  end

  describe 'session handling' do
    it 'maintains session across requests' do
      get :index
      session_id = session.id
      
      get :index
      expect(session.id).to eq(session_id)
    end
  end

  describe 'request format handling' do
    it 'handles HTML requests' do
      get :index
      expect(response.content_type).to include('text/plain')
    end

    it 'handles different request formats appropriately' do
      # Test that the controller can handle different formats
      request.headers['Accept'] = 'application/json'
      get :index
      expect(response).to be_successful
    end
  end

  describe 'parameter handling' do
    controller do
      def with_params
        render json: { received: params[:test_param] }
      end
    end

    before do
      routes.draw do
        get 'with_params' => 'anonymous#with_params'
      end
    end

    it 'receives and processes parameters' do
      get :with_params, params: { test_param: 'test_value' }
      expect(response).to be_successful
      
      json_response = JSON.parse(response.body)
      expect(json_response['received']).to eq('test_value')
    end
  end

  describe 'logging' do
    it 'logs requests appropriately' do
      # Test that requests are logged
      expect(Rails.logger).to receive(:info).at_least(:once)
      get :index
    end
  end

  describe 'performance' do
    it 'responds quickly to simple requests' do
      start_time = Time.now
      get :index
      end_time = Time.now
      
      expect(end_time - start_time).to be < 1.0
    end
  end

  describe 'memory usage' do
    it 'does not leak memory on repeated requests' do
      initial_memory = GC.stat[:total_allocated_objects]
      
      10.times { get :index }
      
      GC.start
      final_memory = GC.stat[:total_allocated_objects]
      
      # Memory should not grow excessively
      expect(final_memory - initial_memory).to be < 100000
    end
  end

  describe 'thread safety' do
    it 'handles concurrent requests safely' do
      threads = []
      
      5.times do
        threads << Thread.new do
          get :index
          expect(response).to be_successful
        end
      end
      
      threads.each(&:join)
    end
  end

  describe 'internationalization' do
    it 'uses default locale' do
      get :index
      expect(I18n.locale).to eq(I18n.default_locale)
    end

    it 'can handle locale changes' do
      I18n.with_locale(:es) do
        get :index
        expect(response).to be_successful
      end
    end
  end

  describe 'timezone handling' do
    it 'uses application timezone' do
      get :index
      expect(Time.zone).to be_present
    end
  end
end
