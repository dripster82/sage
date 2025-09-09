# frozen_string_literal: true

# app/controllers/api/v1/admin_users/tokens_controller.rb
module Api
  module V1
    module AdminUsers
      class TokensController < Api::V1::BaseController
        include Authenticable

        # Skip authentication for refresh action since it handles its own token validation
        skip_before_action :authenticate_admin_user!, only: [:refresh]

        # Handle token service specific errors - these need to be more specific than StandardError
        rescue_from ::AdminUsers::TokenService::DeviceMismatchError, with: :handle_device_mismatch_error
        rescue_from ::AdminUsers::TokenService::TokenReuseError, with: :handle_token_reuse_error
        rescue_from ::AdminUsers::TokenService::InvalidTokenFamilyError, with: :handle_invalid_token_family_error

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
              admin_user = AdminUser.find(decoded_refresh_token['admin_user_id'])
              validate_access_token_for_legacy_mode(admin_user)

              # For legacy mode, just return a new access token without rotating refresh token
              new_access_token = token_service.encode_user_token(admin_user.id)
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
            Rails.logger.error "Admin User Not Found: #{e.message}"
            render json: { error: "Invalid refresh token" }, status: :unauthorized
          rescue ::AdminUsers::TokenService::DeviceMismatchError => e
            Rails.logger.error "Device Mismatch Error: #{e.message}"
            render json: { error: "Device mismatch detected" }, status: :unauthorized
          rescue ::AdminUsers::TokenService::TokenReuseError => e
            Rails.logger.error "Token Reuse Error: #{e.message}"
            render json: { error: "Token reuse detected" }, status: :unauthorized
          rescue ::AdminUsers::TokenService::InvalidTokenFamilyError => e
            Rails.logger.error "Invalid Token Family Error: #{e.message}"
            render json: { error: "Invalid token family" }, status: :unauthorized
          rescue StandardError => e
            Rails.logger.error "Token refresh error: #{e.message}"
            Rails.logger.error "Backtrace: #{e.backtrace.join('\n')}"
            if e.message == "Access token not provided"
              render json: { error: "Token not provided" }, status: :unauthorized
            else
              render json: { error: "Invalid refresh token" }, status: :unauthorized
            end
          end
        end

        private

        def validate_access_token_for_legacy_mode(admin_user)
          # For legacy mode, we need to validate that the access token matches the refresh token
          token = request.headers["Authorization"]
          if token.present?
            begin
              # remove Bearer from token string
              token = token.gsub('Bearer ', '')
              decoded_token = token_service.decode_token(token)
              unless decoded_token["admin_user_id"] == admin_user.id
                raise StandardError, "Admin User Token didn't match Refresh Token"
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
          ::AdminUsers::TokenService
        end
      end
    end
  end
end
