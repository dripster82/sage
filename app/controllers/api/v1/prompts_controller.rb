# frozen_string_literal: true

module Api
  module V1
    class PromptsController < BaseController
      # Include JWT authentication
      include Authenticable

      # Handle specific errors from the PromptProcessingService
      # Order matters: more specific errors should come before general ones
      rescue_from PromptProcessingService::PromptNotFoundError, with: :handle_prompt_not_found
      rescue_from PromptProcessingService::MissingParameterError, with: :handle_missing_parameter

      def process_prompt
        validate_required_params
        
        service = create_processing_service
        result = service.process_and_query(
          prompt_key: params[:prompt],
          query: params[:query],
          parameters: extract_additional_parameters,
          chat_id: params[:chat_id]
        )
        
        render_success({
          response: result[:response].content,
          prompt_name: result[:prompt].name,
          original_query: result[:original_query],
          ai_log_id: result[:ai_log].id,
          processed_prompt: result[:processed_prompt]
        })
      end

      private

      def validate_required_params
        raise PromptProcessingService::MissingParameterError, 'Prompt parameter is required' if params[:prompt].blank?
        raise PromptProcessingService::MissingParameterError, 'Query parameter is required' if params[:query].blank?
      end

      def create_processing_service
        temperature = params[:temperature]&.to_f || 0.7
        model = params[:model]
        
        PromptProcessingService.new(temperature: temperature, model: model)
      end

      def extract_additional_parameters
        # Extract all parameters except the reserved ones
        reserved_params = %w[prompt query chat_id temperature model controller action format]
        params.except(*reserved_params).to_unsafe_h
      end

      def handle_prompt_not_found(exception)
        render_error(exception.message, status: :not_found)
      end

      def handle_missing_parameter(exception)
        render_error(exception.message, status: :bad_request)
      end
    end
  end
end
