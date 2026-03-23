# frozen_string_literal: true

module Api
  module V1
    class UserPromptFlowsController < BaseController
      include Authenticable

      before_action :authenticate_user!

      def process_prompt_flow
        flow_name = params[:prompt_flow].to_s
        return render_error('Prompt flow parameter is required') if flow_name.blank?

        flow = PromptFlow.current.find_by!(name: flow_name)

        validation_errors = PromptFlowValidationService.new(flow).call
        return render_error('Validation failed', details: validation_errors) if validation_errors.any?

        unless @current_user.has_sufficient_credits?(flow.credits)
          return render_error(
            "Insufficient credits. Required: #{flow.credits}, Available: #{@current_user.credits}",
            status: :payment_required
          )
        end

        execution = PromptFlowExecutionService.new(flow).execute(inputs: execution_inputs)
        @current_user.deduct_credits!(flow.credits)

        render_success({
          prompt_flow_name: flow.name,
          execution_id: execution.id,
          status: execution.status,
          outputs: execution.outputs,
          cost: flow.credits,
          credits_remaining: @current_user.credits
        })
      rescue ActiveRecord::RecordNotFound
        render_error("Prompt flow not found: #{flow_name}", status: :not_found)
      end

      private

      def execution_inputs
        reserved = %w[prompt_flow controller action format]
        payload_inputs = params[:inputs]
        payload_inputs = payload_inputs.to_unsafe_h if payload_inputs.is_a?(ActionController::Parameters)
        payload_inputs = payload_inputs.to_h if payload_inputs.respond_to?(:to_h)
        top_level_inputs = params.except(*reserved).to_unsafe_h
        top_level_inputs.except('inputs').merge(payload_inputs || {})
      end
    end
  end
end
