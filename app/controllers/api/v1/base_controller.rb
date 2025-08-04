# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      # Skip CSRF protection for API requests
      skip_before_action :verify_authenticity_token
      
      # Set default response format to JSON
      before_action :set_default_response_format
      
      # Handle errors with JSON responses
      rescue_from StandardError, with: :handle_standard_error
      rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
      rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
      
      private
      
      def set_default_response_format
        request.format = :json
      end
      
      def handle_standard_error(exception)
        Rails.logger.error "API Error: #{exception.message}"
        Rails.logger.error exception.backtrace.join("\n")
        
        render json: {
          error: 'Internal server error',
          message: exception.message
        }, status: :internal_server_error
      end
      
      def handle_not_found(exception)
        render json: {
          error: 'Not found',
          message: exception.message
        }, status: :not_found
      end
      
      def handle_parameter_missing(exception)
        render json: {
          error: 'Missing parameter',
          message: exception.message
        }, status: :bad_request
      end
      
      def render_success(data = {}, status: :ok)
        render json: { success: true, data: data }, status: status
      end
      
      def render_error(message, status: :bad_request, details: nil)
        error_response = { success: false, error: message }
        error_response[:details] = details if details
        render json: error_response, status: status
      end
    end
  end
end
