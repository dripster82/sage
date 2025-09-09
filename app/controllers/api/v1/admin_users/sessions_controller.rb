# frozen_string_literal: true

# app/controllers/api/v1/admin_users/sessions_controller.rb
module Api
  module V1
    module AdminUsers
      class SessionsController < Api::V1::BaseController
        def create
          begin
            admin_user = AdminUser.find_for_database_authentication(email: params[:email])

            if admin_user&.valid_password?(params[:password])
              # Check for legacy client support
              if request.headers['X-Legacy-Client'] == 'true'
                # Legacy token generation for backward compatibility
                token = token_service.encode_user_token(admin_user.id)
                refresh_token = token_service.encode_refresh_token(admin_user.id)
                render json: { auth_token: token, refresh_token: refresh_token }, status: :ok
              else
                # Generate device fingerprint from server-side request data
                device_fingerprint = DeviceFingerprintService.generate_from_request(request)

                # New device-bound token generation
                tokens = token_service.issue_token_with_rotation(admin_user, device_fingerprint)
                render json: { auth_token: tokens[:access_token], refresh_token: tokens[:refresh_token] }, status: :ok
              end
            else
              render json: { error: "Invalid email or password" }, status: :unauthorized
            end
          rescue => e
            Rails.logger.error("Error during admin user sign-in: #{e.message}")
            render json: { error: "Something went wrong" }, status: :internal_server_error
          end
        end

        private

        def token_service
          ::AdminUsers::TokenService
        end
      end
    end
  end
end
