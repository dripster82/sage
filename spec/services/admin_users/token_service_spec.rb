# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminUsers::TokenService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:admin_user_id) { admin_user.id }

  describe '.encode_user_token' do
    it 'creates a valid JWT token with admin_user_id' do
      token = described_class.encode_user_token(admin_user_id)

      expect(token).to be_present
      expect(token).to be_a(String)

      # Decode and verify the token
      decoded_token = described_class.decode_token(token)
      expect(decoded_token['admin_user_id']).to eq(admin_user_id)
      expect(decoded_token['exp']).to be > Time.now.to_i
    end

    it 'creates token with 5 minute expiration by default' do
      token = described_class.encode_user_token(admin_user_id)
      decoded_token = described_class.decode_token(token)

      expected_exp = Time.now.to_i + (5 * 60) # 5 minutes
      expect(decoded_token['exp']).to be_within(5).of(expected_exp)
    end
  end

  describe '.issue_token_with_rotation' do
    let(:device_fingerprint) { 'hashed-device-fingerprint' }

    it 'creates access token and refresh token with token family' do
      result = described_class.issue_token_with_rotation(admin_user, device_fingerprint)

      expect(result).to have_key(:access_token)
      expect(result).to have_key(:refresh_token)

      # Verify access token
      access_payload = described_class.decode_token(result[:access_token])
      expect(access_payload['admin_user_id']).to eq(admin_user.id)

      # Verify refresh token
      refresh_payload = described_class.decode_token(result[:refresh_token])
      expect(refresh_payload['admin_user_id']).to eq(admin_user.id)
      expect(refresh_payload['family_id']).to be_present
      expect(refresh_payload['token_id']).to be_present
      expect(refresh_payload['device_fingerprint']).to eq(device_fingerprint)
      expect(refresh_payload['version']).to eq(1)
    end

    it 'creates token family record in database' do
      expect {
        described_class.issue_token_with_rotation(admin_user, device_fingerprint)
      }.to change { TokenFamily.count }.by(1)

      token_family = TokenFamily.last
      expect(token_family.admin_user).to eq(admin_user)
      expect(token_family.device_fingerprint).to eq(device_fingerprint)
      expect(token_family.version).to eq(1)
    end
  end

  describe '.rotate_refresh_token' do
    let(:device_fingerprint) { 'hashed-device-fingerprint' }
    let!(:token_family) { create(:token_family, admin_user: admin_user, device_fingerprint: device_fingerprint, version: 1) }
    let(:refresh_token) do
      described_class.encode_refresh_token_with_metadata(
        admin_user.id,
        token_family.family_id,
        token_family.latest_token_id,
        device_fingerprint,
        1
      )
    end

    it 'rotates tokens successfully with matching device fingerprint' do
      result = described_class.rotate_refresh_token(refresh_token, device_fingerprint)

      expect(result).to have_key(:access_token)
      expect(result).to have_key(:refresh_token)

      # Verify new tokens
      access_payload = described_class.decode_token(result[:access_token])
      refresh_payload = described_class.decode_token(result[:refresh_token])

      expect(access_payload['admin_user_id']).to eq(admin_user.id)
      expect(refresh_payload['version']).to eq(2)
      expect(refresh_payload['token_id']).not_to eq(token_family.latest_token_id)
    end

    it 'updates token family with new version and token id' do
      described_class.rotate_refresh_token(refresh_token, device_fingerprint)

      token_family.reload
      expect(token_family.version).to eq(2)
    end

    it 'raises error for device fingerprint mismatch' do
      wrong_fingerprint = 'wrong-fingerprint'

      expect {
        described_class.rotate_refresh_token(refresh_token, wrong_fingerprint)
      }.to raise_error(described_class::DeviceMismatchError)

      # Token family should be deleted
      expect(TokenFamily.find_by(id: token_family.id)).to be_nil
    end

    it 'raises error for token reuse detection' do
      # First rotation
      described_class.rotate_refresh_token(refresh_token, device_fingerprint)

      # Try to use the same token again
      expect {
        described_class.rotate_refresh_token(refresh_token, device_fingerprint)
      }.to raise_error(described_class::TokenReuseError)
    end

    it 'raises error for invalid token family' do
      invalid_token = described_class.encode_refresh_token_with_metadata(
        admin_user.id,
        'non-existent-family-id',
        'some-token-id',
        device_fingerprint,
        1
      )

      expect {
        described_class.rotate_refresh_token(invalid_token, device_fingerprint)
      }.to raise_error(described_class::InvalidTokenFamilyError)
    end
  end

  describe '.logout_session' do
    let(:device_fingerprint) { 'hashed-device-fingerprint' }
    let!(:token_family) { create(:token_family, admin_user: admin_user, device_fingerprint: device_fingerprint) }
    let(:refresh_token) do
      described_class.encode_refresh_token_with_metadata(
        admin_user.id,
        token_family.family_id,
        token_family.latest_token_id,
        device_fingerprint,
        token_family.version
      )
    end

    it 'deletes token family and returns success' do
      result = described_class.logout_session(refresh_token)

      expect(result[:success]).to be true
      expect(result[:message]).to eq('Successfully logged out')
      expect(TokenFamily.find_by(id: token_family.id)).to be_nil
    end

    it 'handles invalid tokens gracefully' do
      invalid_token = 'invalid.token.here'

      result = described_class.logout_session(invalid_token)

      expect(result[:success]).to be false
      expect(result[:message]).to eq('Invalid session')
    end
  end

  describe '.logout_all_sessions' do
    let!(:token_families) { create_list(:token_family, 3, admin_user: admin_user) }
    let!(:other_user_families) { create_list(:token_family, 2, admin_user: create(:admin_user)) }

    it 'deletes all token families for the user' do
      result = described_class.logout_all_sessions(admin_user.id)

      expect(result[:success]).to be true
      expect(result[:sessions_terminated]).to eq(3)
      expect(TokenFamily.where(admin_user: admin_user)).to be_empty
      expect(TokenFamily.count).to eq(2) # Other user's families remain
    end

    it 'returns zero count when user has no sessions' do
      user_with_no_sessions = create(:admin_user)

      result = described_class.logout_all_sessions(user_with_no_sessions.id)

      expect(result[:success]).to be true
      expect(result[:sessions_terminated]).to eq(0)
    end

    it 'creates token with custom timeout' do
      custom_timeout = 1.hour.to_i
      token = described_class.encode_user_token(admin_user_id, timeout: custom_timeout)
      
      decoded_token = described_class.decode_token(token)
      expected_exp = Time.now.to_i + custom_timeout
      
      # Allow for small time difference in test execution
      expect(decoded_token['exp']).to be_within(5).of(expected_exp)
    end
  end

  describe '.encode_refresh_token' do
    it 'creates a valid refresh token with admin_user_id' do
      token = described_class.encode_refresh_token(admin_user_id)
      
      expect(token).to be_present
      expect(token).to be_a(String)
      
      # Decode and verify the token
      decoded_token = described_class.decode_token(token)
      expect(decoded_token['admin_user_id']).to eq(admin_user_id)
      expect(decoded_token['exp']).to be > Time.now.to_i
    end

    it 'creates refresh token with longer expiration than user token' do
      user_token = described_class.encode_user_token(admin_user_id)
      refresh_token = described_class.encode_refresh_token(admin_user_id)
      
      user_decoded = described_class.decode_token(user_token)
      refresh_decoded = described_class.decode_token(refresh_token)
      
      expect(refresh_decoded['exp']).to be > user_decoded['exp']
    end
  end

  describe '.decode_token' do
    it 'successfully decodes a valid token' do
      token = described_class.encode_user_token(admin_user_id)
      decoded_token = described_class.decode_token(token)
      
      expect(decoded_token).to be_a(Hash)
      expect(decoded_token['admin_user_id']).to eq(admin_user_id)
    end

    it 'raises error for invalid token' do
      expect {
        described_class.decode_token('invalid_token')
      }.to raise_error(JWT::DecodeError)
    end

    it 'raises error for expired token' do
      # Create an expired token
      expired_payload = { admin_user_id: admin_user_id, exp: 1.hour.ago.to_i }
      expired_token = JWT.encode(expired_payload, Rails.application.secret_key_base)
      
      expect {
        described_class.decode_token(expired_token)
      }.to raise_error(JWT::ExpiredSignature)
    end
  end
end
