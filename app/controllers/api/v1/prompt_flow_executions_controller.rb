# frozen_string_literal: true

module Api
  module V1
    class PromptFlowExecutionsController < BaseController
      include Authenticable

      before_action :authenticate_admin_user!
      before_action :set_prompt_flow

      def index
        executions = @prompt_flow.executions.order(created_at: :desc)
        render_success({
          executions: executions.as_json
        })
      end

      def show
        execution = @prompt_flow.executions.find(params[:id])
        render_success({ execution: execution.as_json })
      end

      private

      def set_prompt_flow
        @prompt_flow = PromptFlow.find(params[:prompt_flow_id])
      end
    end
  end
end
