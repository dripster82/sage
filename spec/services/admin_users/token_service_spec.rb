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
