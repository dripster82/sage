# frozen_string_literal: true

# app/controllers/concerns/authenticable.rb
module Authenticable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_admin_user!
  end

  def authenticate_admin_user!
    token = request.headers["Authorization"]
    if token.present?
      begin
        if token == "dev" && Rails.env.development?
          @current_admin_user = AdminUser.first
          return
        end
        # remove Bearer from token string
        token = token.gsub('Bearer ', '')
        decoded_token = AdminUsers::TokenService.decode_token(token)
        @current_admin_user = AdminUser.find(decoded_token["admin_user_id"])

        # Validate token_id exists in active TokenFamily (for device-bound tokens)
        if decoded_token['token_id']
          token_family = TokenFamily.find_by(
            admin_user: @current_admin_user,
            latest_token_id: decoded_token['token_id']
          )

          unless token_family
            Rails.logger.error("Token has been invalidated: token_id=#{decoded_token['token_id']}")
            return render json: { error: "Token has been invalidated" }, status: :unauthorized
          end
        end
        # If no token_id, it's a legacy token (backward compatibility)

      rescue => e
        Rails.logger.error("Authentication error: #{e.message}")
        render json: { error: "Invalid token" }, status: :unauthorized
      end
    else
      render json: { error: "Token not provided" }, status: :unauthorized
    end
  end

  def current_admin_user
    @current_admin_user
  end
end
