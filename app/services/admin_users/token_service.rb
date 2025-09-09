# frozen_string_literal: true

module AdminUsers
  class TokenService
    # Custom error classes
    class DeviceMismatchError < StandardError; end
    class TokenReuseError < StandardError; end
    class InvalidTokenFamilyError < StandardError; end

    def self.encode_user_token(admin_user_id, timeout: 5 * 60) # 5 minutes
      payload = { admin_user_id: admin_user_id, exp: Time.now.to_i + timeout }
      encode(payload)
    end

    def self.encode_user_token_with_token_id(admin_user_id, token_id, timeout: 5 * 60) # 5 minutes
      payload = {
        admin_user_id: admin_user_id,
        token_id: token_id,
        exp: Time.now.to_i + timeout
      }
      encode(payload)
    end

    def self.encode_refresh_token(admin_user_id, timeout: 7 * 86_400) # 7 days
      payload = { admin_user_id: admin_user_id, exp: Time.now.to_i + timeout }
      encode(payload)
    end

    def self.encode_refresh_token_with_metadata(admin_user_id, family_id, token_id, device_fingerprint, version, timeout: 7 * 86_400)
      payload = {
        admin_user_id: admin_user_id,
        family_id: family_id,
        token_id: token_id,
        device_fingerprint: device_fingerprint,
        version: version,
        exp: Time.now.to_i + timeout
      }
      encode(payload)
    end

    def self.issue_token_with_rotation(admin_user, device_fingerprint)
      family_id = SecureRandom.uuid
      token_id = SecureRandom.uuid

      # Create access token with token_id
      access_token = encode_user_token_with_token_id(admin_user.id, token_id)

      # Create refresh token with metadata
      refresh_token = encode_refresh_token_with_metadata(
        admin_user.id,
        family_id,
        token_id,
        device_fingerprint,
        1
      )

      # Store token family
      TokenFamily.create!(
        family_id: family_id,
        admin_user: admin_user,
        latest_token_id: token_id,
        version: 1,
        device_fingerprint: device_fingerprint
      )

      { access_token: access_token, refresh_token: refresh_token }
    end

    def self.rotate_refresh_token(old_token, device_fingerprint)
      payload = decode_token(old_token)

      # Get token family
      token_family = TokenFamily.find_by_family_id(payload['family_id'])
      raise InvalidTokenFamilyError, 'Invalid token family' unless token_family

      # Verify device binding
      if token_family.device_fingerprint != device_fingerprint
        raise DeviceMismatchError, 'Device mismatch detected'
      end

      # Verify token version and detect reuse
      if token_family.version != payload['version'] || token_family.latest_token_id != payload['token_id']
        raise TokenReuseError, 'Token reuse detected'
      end

      # Generate new tokens
      new_token_id = SecureRandom.uuid
      new_version = payload['version'] + 1

      # Update token family
      token_family.update_token!(new_token_id)

      # Generate new tokens
      access_token = encode_user_token_with_token_id(payload['admin_user_id'], new_token_id)
      refresh_token = encode_refresh_token_with_metadata(
        payload['admin_user_id'],
        payload['family_id'],
        new_token_id,
        device_fingerprint,
        new_version
      )

      { access_token: access_token, refresh_token: refresh_token }
    end

    def self.logout_session(refresh_token)
      begin
        payload = decode_token(refresh_token)
        token_family = TokenFamily.find_by_family_id(payload['family_id'])
        token_family&.destroy
        { success: true, message: 'Successfully logged out' }
      rescue => e
        { success: false, message: 'Invalid session' }
      end
    end

    def self.logout_all_sessions(admin_user_id)
      sessions_terminated = TokenFamily.delete_all_for_user(admin_user_id)
      { success: true, sessions_terminated: sessions_terminated }
    end

    def self.decode_token(token)
      JWT.decode(token, Rails.application.secret_key_base)[0]
    end

    def self.encode(payload)
      JWT.encode(payload, Rails.application.secret_key_base)
    end
  end
end
