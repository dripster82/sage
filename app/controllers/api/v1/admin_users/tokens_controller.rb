# frozen_string_literal: true

# app/controllers/api/v1/admin_users/tokens_controller.rb
module Api
  module V1
    module AdminUsers
      class TokensController < Api::V1::BaseController
        include Authenticable

        def refresh
          refresh_token = params[:refresh_token]

          begin
            # Decode refresh token
            decoded_refresh_token = token_service.decode_token(refresh_token)
            validate_refresh_token_payload(decoded_refresh_token)

            # Generate new access token
            new_access_token = token_service.encode_user_token(@current_admin_user.id)
            render json: { auth_token: new_access_token }, status: :ok
          rescue => e
            Rails.logger.error "Refresh Token Error: #{e.message}"
            render json: { error: "Invalid refresh token" }, status: :unauthorized
          end
        end

        private

        def validate_refresh_token_payload(payload)
          return if payload.dig('admin_user_id') == @current_admin_user.id

          raise "Admin User Token didn't match Refresh Token"
        end

        def token_service
          ::AdminUsers::TokenService
        end
      end
    end
  end
end
