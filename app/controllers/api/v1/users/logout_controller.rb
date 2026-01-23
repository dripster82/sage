# frozen_string_literal: true

module Api
  module V1
    module Users
      class LogoutController < ApplicationController
        include Authenticable

        before_action :authenticate_user!

        def logout
          refresh_token = params[:refresh_token]

          if refresh_token.blank?
            render json: { error: "Refresh token is required" }, status: :bad_request
            return
          end

          result = token_service.logout_session(refresh_token)

          if result[:success]
            render json: { message: result[:message] }, status: :ok
          else
            render json: { error: result[:message] }, status: :bad_request
          end
        end

        def logout_all
          result = token_service.logout_all_sessions(@current_user.id)
          render json: { 
            message: "Successfully logged out from all devices",
            sessions_terminated: result[:sessions_terminated]
          }, status: :ok
        end

        private

        def token_service
          ::Users::TokenService
        end
      end
    end
  end
end

