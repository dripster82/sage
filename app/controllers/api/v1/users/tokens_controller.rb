# frozen_string_literal: true

module Api
  module V1
    module Users
      class TokensController < Api::V1::BaseController
        include Authenticable

        # Skip authentication for refresh action since it handles its own token validation
        skip_before_action :authenticate_user!, only: [:refresh]

        # Handle token service specific errors
        rescue_from ::Users::TokenService::DeviceMismatchError, with: :handle_device_mismatch_error
        rescue_from ::Users::TokenService::TokenReuseError, with: :handle_token_reuse_error
        rescue_from ::Users::TokenService::InvalidTokenFamilyError, with: :handle_invalid_token_family_error

        def refresh
          refresh_token = params[:refresh_token]

          # Validate refresh token is present
          if refresh_token.blank?
            render json: { error: "Refresh token is required" }, status: :bad_request
            return
          end

          begin
            # Check if this is a legacy refresh token (no family_id)
            decoded_refresh_token = token_service.decode_token(refresh_token)

            if decoded_refresh_token['family_id'].nil?
              # Handle legacy refresh token
              user = User.find(decoded_refresh_token['user_id'])
              validate_access_token_for_legacy_mode(user)

              # For legacy mode, just return a new access token without rotating refresh token
              new_access_token = token_service.encode_user_token(user.id)
              user.update_last_seen!
              render json: { auth_token: new_access_token }, status: :ok
            else
              # Handle device-bound refresh token
              device_fingerprint = DeviceFingerprintService.generate_from_request(request)
              tokens = token_service.rotate_refresh_token(refresh_token, device_fingerprint)
              render json: { auth_token: tokens[:access_token], refresh_token: tokens[:refresh_token] }, status: :ok
            end

          rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::InvalidIssuerError, JWT::InvalidIatError => e
            Rails.logger.error "JWT Error: #{e.message}"
            render json: { error: "Invalid refresh token" }, status: :unauthorized
          rescue ActiveRecord::RecordNotFound => e
            Rails.logger.error "User Not Found: #{e.message}"
            render json: { error: "Invalid refresh token" }, status: :unauthorized
          rescue StandardError => e
            Rails.logger.error "Token refresh error: #{e.message}"
            if e.message == "Access token not provided"
              render json: { error: "Token not provided" }, status: :unauthorized
            else
              render json: { error: "Invalid refresh token" }, status: :unauthorized
            end
          end
        end

        private

        def validate_access_token_for_legacy_mode(user)
          token = request.headers["Authorization"]
          if token.present?
            begin
              token = token.gsub('Bearer ', '')
              decoded_token = token_service.decode_token(token)
              unless decoded_token["user_id"] == user.id
                raise StandardError, "User Token didn't match Refresh Token"
              end
            rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::InvalidIssuerError, JWT::InvalidIatError => e
              Rails.logger.error("JWT validation error: #{e.message}")
              raise StandardError, "Invalid access token"
            rescue => e
              Rails.logger.error("Access token validation error: #{e.message}")
              raise StandardError, "Invalid access token"
            end
          else
            raise StandardError, "Access token not provided"
          end
        end

        def handle_device_mismatch_error(exception)
          Rails.logger.error "Device Mismatch Error: #{exception.message}"
          render json: { error: "Device mismatch detected" }, status: :unauthorized
        end

        def handle_token_reuse_error(exception)
          Rails.logger.error "Token Reuse Error: #{exception.message}"
          render json: { error: "Token reuse detected" }, status: :unauthorized
        end

        def handle_invalid_token_family_error(exception)
          Rails.logger.error "Invalid Token Family Error: #{exception.message}"
          render json: { error: "Invalid token family" }, status: :unauthorized
        end

        def token_service
          ::Users::TokenService
        end
      end
    end
  end
end

