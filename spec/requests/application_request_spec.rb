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
end
