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
              token = token_service.encode_user_token(admin_user.id)
              refresh_token = token_service.encode_refresh_token(admin_user.id) # New method for refresh token
              render json: { auth_token: token, refresh_token: refresh_token }, status: :ok
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
