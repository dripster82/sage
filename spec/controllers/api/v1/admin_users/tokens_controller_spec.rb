# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::AdminUsers::TokensController, type: :controller do
  let(:admin_user) { create(:admin_user) }
  let(:valid_token) { AdminUsers::TokenService.encode_user_token(admin_user.id) }
  let(:valid_refresh_token) { AdminUsers::TokenService.encode_refresh_token(admin_user.id) }

  # For device-bound token tests, we need tokens with token_id
  let(:test_token_id) { SecureRandom.uuid }
  let(:valid_token_with_token_id) { AdminUsers::TokenService.encode_user_token_with_token_id(admin_user.id, test_token_id) }

  describe 'POST #refresh' do
    context 'with device-bound tokens' do
      # Create a consistent device fingerprint for testing
      let(:device_fingerprint) { 'test-device-fingerprint-hash' }
      let!(:token_family) { create(:token_family, admin_user: admin_user, device_fingerprint: device_fingerprint, version: 1, latest_token_id: test_token_id) }
      let(:device_bound_refresh_token) do
        AdminUsers::TokenService.encode_refresh_token_with_metadata(
          admin_user.id,
          token_family.family_id,
          token_family.latest_token_id,
          device_fingerprint,
          1
        )
      end

      before do
        request.headers['Authorization'] = "Bearer #{valid_token_with_token_id}"
        # Set up consistent request headers for device fingerprinting
        request.headers['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        request.headers['Accept-Language'] = 'en-US,en;q=0.9'
        request.headers['Accept-Encoding'] = 'gzip, deflate, br'

        # Mock the DeviceFingerprintService to return our test fingerprint
        allow(DeviceFingerprintService).to receive(:generate_from_request).and_return(device_fingerprint)
      end

      it 'rotates tokens successfully with matching device fingerprint' do
        post :refresh, params: { refresh_token: device_bound_refresh_token }, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response['auth_token']).to be_present
        expect(json_response['refresh_token']).to be_present

        # Verify the new tokens
        decoded_access_token = AdminUsers::TokenService.decode_token(json_response['auth_token'])
        decoded_refresh_token = AdminUsers::TokenService.decode_token(json_response['refresh_token'])

        expect(decoded_access_token['admin_user_id']).to eq(admin_user.id)
        expect(decoded_refresh_token['admin_user_id']).to eq(admin_user.id)
        expect(decoded_refresh_token['version']).to eq(2)
        expect(decoded_refresh_token['device_fingerprint']).to eq(device_fingerprint)
      end

      it 'updates token family version' do
        post :refresh, params: { refresh_token: device_bound_refresh_token }, format: :json

        token_family.reload
        expect(token_family.version).to eq(2)
      end

      it 'returns error for device fingerprint mismatch' do
        # Mock a different device fingerprint to simulate device mismatch
        allow(DeviceFingerprintService).to receive(:generate_from_request).and_return('different-device-fingerprint')

        post :refresh, params: { refresh_token: device_bound_refresh_token }, format: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Device mismatch detected')

        # Token family should still exist (not destroyed on device mismatch)
        expect(TokenFamily.find_by(id: token_family.id)).to be_present
      end

      it 'returns error for token reuse detection' do
        # First rotation
        post :refresh, params: { refresh_token: device_bound_refresh_token }, format: :json
        expect(response).to have_http_status(:ok)

        # Try to use the same token again
        post :refresh, params: { refresh_token: device_bound_refresh_token }, format: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Token reuse detected')
      end


    end

    context 'with legacy tokens (backward compatibility)' do
      before do
        request.headers['Authorization'] = "Bearer #{valid_token}"
        request.headers['X-Legacy-Client'] = 'true'
      end

      it 'returns new access token for legacy refresh tokens' do
        post :refresh, params: { refresh_token: valid_refresh_token }, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response['auth_token']).to be_present
        expect(json_response['refresh_token']).to be_nil # Legacy mode doesn't rotate refresh tokens

        # Verify the new token is valid and contains correct admin_user_id
        decoded_token = AdminUsers::TokenService.decode_token(json_response['auth_token'])
        expect(decoded_token['admin_user_id']).to eq(admin_user.id)
      end
    end

    context 'without authorization token' do
      before do
        # Mock DeviceFingerprintService for these error cases
        allow(DeviceFingerprintService).to receive(:generate_from_request).and_return('test-fingerprint')
      end

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
        # Mock DeviceFingerprintService for these error cases
        allow(DeviceFingerprintService).to receive(:generate_from_request).and_return('test-fingerprint')
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
        # Mock DeviceFingerprintService for these error cases
        allow(DeviceFingerprintService).to receive(:generate_from_request).and_return('test-fingerprint')
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
        # Mock DeviceFingerprintService for these error cases
        allow(DeviceFingerprintService).to receive(:generate_from_request).and_return('test-fingerprint')
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
