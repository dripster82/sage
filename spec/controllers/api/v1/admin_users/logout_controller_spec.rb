# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::AdminUsers::LogoutController, type: :controller do
  let(:admin_user) { create(:admin_user) }
  let(:valid_token) { AdminUsers::TokenService.encode_user_token(admin_user.id) }
  let(:device_fingerprint) { 'hashed-device-fingerprint' }

  before do
    request.headers['Authorization'] = "Bearer #{valid_token}"
  end

  describe 'POST #logout' do
    context 'with device-bound refresh token' do
      let!(:token_family) { create(:token_family, admin_user: admin_user, device_fingerprint: device_fingerprint) }
      let(:refresh_token) do
        AdminUsers::TokenService.encode_refresh_token_with_metadata(
          admin_user.id,
          token_family.family_id,
          token_family.latest_token_id,
          device_fingerprint,
          token_family.version
        )
      end

      it 'logs out successfully and deletes token family' do
        post :logout, params: { refresh_token: refresh_token }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Successfully logged out')
        
        # Verify token family is deleted
        expect(TokenFamily.find_by(id: token_family.id)).to be_nil
      end
    end

    context 'with invalid refresh token' do
      it 'returns error for invalid token' do
        post :logout, params: { refresh_token: 'invalid.token.here' }, format: :json
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid session')
      end
    end

    context 'with missing refresh token' do
      it 'returns error for missing token' do
        post :logout, format: :json
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Refresh token is required')
      end
    end

    context 'with legacy refresh token' do
      let(:legacy_refresh_token) { AdminUsers::TokenService.encode_refresh_token(admin_user.id) }

      it 'handles legacy tokens gracefully' do
        post :logout, params: { refresh_token: legacy_refresh_token }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Successfully logged out')
      end
    end
  end

  describe 'POST #logout_all' do
    let!(:token_families) { create_list(:token_family, 3, admin_user: admin_user) }
    let!(:other_user_families) { create_list(:token_family, 2, admin_user: create(:admin_user)) }

    it 'logs out all sessions for the current user' do
      post :logout_all, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['message']).to eq('Successfully logged out from all devices')
      expect(json_response['sessions_terminated']).to eq(3)
      
      # Verify all user's token families are deleted
      expect(TokenFamily.where(admin_user: admin_user)).to be_empty
      # Verify other users' token families remain
      expect(TokenFamily.count).to eq(2)
    end

    it 'handles user with no active sessions' do
      user_with_no_sessions = create(:admin_user)
      token = AdminUsers::TokenService.encode_user_token(user_with_no_sessions.id)
      request.headers['Authorization'] = "Bearer #{token}"
      
      post :logout_all, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['message']).to eq('Successfully logged out from all devices')
      expect(json_response['sessions_terminated']).to eq(0)
    end
  end
end
