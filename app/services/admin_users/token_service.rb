# frozen_string_literal: true

module AdminUsers
  class TokenService
    def self.encode_user_token(admin_user_id, timeout: 4 * 3600)
      payload = { admin_user_id: admin_user_id, exp: Time.now.to_i + timeout } # User token expires in 4 hours
      encode(payload)
    end

    def self.encode_refresh_token(admin_user_id, timeout: 14 * 86_400)
      payload = { admin_user_id: admin_user_id, exp: Time.now.to_i + timeout } # Refresh token expires in 14 days
      encode(payload)
    end

    def self.decode_token(token)
      JWT.decode(token, Rails.application.secret_key_base)[0]
    end

    def self.encode(payload)
      JWT.encode(payload, Rails.application.secret_key_base)
    end
  end
end
