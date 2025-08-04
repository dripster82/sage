# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::AdminUsers::TokensController, type: :controller do
  let(:admin_user) { create(:admin_user) }
  let(:valid_token) { AdminUsers::TokenService.encode_user_token(admin_user.id) }
  let(:valid_refresh_token) { AdminUsers::TokenService.encode_refresh_token(admin_user.id) }

  describe 'POST #refresh' do
    context 'with valid tokens' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'returns new access token' do
        post :refresh, params: { refresh_token: valid_refresh_token }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        
        expect(json_response['auth_token']).to be_present
        
        # Verify the new token is valid and contains correct admin_user_id
        decoded_token = AdminUsers::TokenService.decode_token(json_response['auth_token'])
        expect(decoded_token['admin_user_id']).to eq(admin_user.id)
      end
    end

    context 'without authorization token' do
      it 'returns unauthorized error' do
        post :refresh, params: { refresh_token: valid_refresh_token }, format: :json
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Token not provided')
      end
    end

    context 'with invalid refresh token' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'returns unauthorized error' do
        post :refresh, params: { refresh_token: 'invalid_refresh_token' }, format: :json
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid refresh token')
      end
    end

    context 'with mismatched admin_user_id in refresh token' do
      let(:other_admin_user) { create(:admin_user) }
      let(:mismatched_refresh_token) { AdminUsers::TokenService.encode_refresh_token(other_admin_user.id) }

      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'returns unauthorized error' do
        post :refresh, params: { refresh_token: mismatched_refresh_token }, format: :json
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid refresh token')
      end
    end

    context 'with expired refresh token' do
      let(:expired_refresh_token) do
        payload = { admin_user_id: admin_user.id, exp: 1.hour.ago.to_i }
        JWT.encode(payload, Rails.application.secret_key_base)
      end

      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
      end

      it 'returns unauthorized error' do
        post :refresh, params: { refresh_token: expired_refresh_token }, format: :json
        
        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid refresh token')
      end
    end
  end
end
