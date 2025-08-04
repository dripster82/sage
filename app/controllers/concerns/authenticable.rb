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
        # remove Bearer from token string
        token = token.gsub('Bearer ', '')
        decoded_token = AdminUsers::TokenService.decode_token(token)
        @current_admin_user = AdminUser.find(decoded_token["admin_user_id"])
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
