# frozen_string_literal: true

module Api
  module V1
    class PromptFlowsController < BaseController
      include Authenticable

      before_action :authenticate_admin_user!
      before_action :set_prompt_flow, only: %i[show update execute]

      def create
        prompt_flow = PromptFlow.new(prompt_flow_params)
        prompt_flow.created_by = current_admin_user
        prompt_flow.updated_by = current_admin_user

        PromptFlow.transaction do
          prompt_flow.save!
          create_nodes_and_edges!(prompt_flow, nodes_params, edges_params)
        end

        render_success(flow_payload(prompt_flow), status: :created)
      rescue ActiveRecord::RecordInvalid => e
        render_error('Validation failed', details: e.record.errors.full_messages)
      end

      def show
        render_success(flow_payload(@prompt_flow))
      end

      def update
        PromptFlow.transaction do
          @prompt_flow.update!(prompt_flow_params.merge(updated_by: current_admin_user))
          replace_nodes_and_edges!(@prompt_flow, nodes_params, edges_params)
        end

        render_success(flow_payload(@prompt_flow))
      rescue ActiveRecord::RecordInvalid => e
        render_error('Validation failed', details: e.record.errors.full_messages)
      end

      def execute
        validation_errors = PromptFlowValidationService.new(@prompt_flow).call
        return render_error('Validation failed', details: validation_errors) if validation_errors.any?

        execution = PromptFlowExecutionService.new(@prompt_flow).execute(inputs: execution_inputs)

        render_success({
          execution_id: execution.id,
          status: execution.status,
          outputs: execution.outputs
        })
      end

      private

      def set_prompt_flow
        @prompt_flow = PromptFlow.find(params[:id])
      end

      def prompt_flow_params
        params.require(:prompt_flow).permit(
          :name,
          :description,
          :status,
          :version_number,
          :is_current,
          :max_executions,
          :credits
        )
      end

      def nodes_params
        nodes = params[:nodes] || []
        nodes = nodes.values if nodes.is_a?(ActionController::Parameters) || nodes.is_a?(Hash)

        nodes.map do |node|
          node = ActionController::Parameters.new(node) unless node.respond_to?(:permit)
          node.permit(
            :temp_id,
            :node_type,
            :prompt_id,
            :position_x,
            :position_y,
            config: {},
            input_ports: {},
            output_ports: {}
          ).to_h
        end
      end

      def edges_params
        edges = params[:edges] || []
        edges = edges.values if edges.is_a?(ActionController::Parameters) || edges.is_a?(Hash)

        edges.reject { |edge| edge.is_a?(String) }.map do |edge|
          edge = ActionController::Parameters.new(edge) unless edge.respond_to?(:permit)
          edge.permit(
            :source_node_id,
            :target_node_id,
            :source_node_temp_id,
            :target_node_temp_id,
            :source_port,
            :target_port,
            :validation_status
          ).to_h
        end
      end

      def execution_inputs
        params[:inputs].presence || {}
      end

      def create_nodes_and_edges!(prompt_flow, nodes, edges)
        node_id_map = {}

        nodes.each do |node_attrs|
          temp_id = node_attrs.delete(:temp_id)
          node = prompt_flow.nodes.create!(node_attrs)
          node_id_map[temp_id] = node.id if temp_id.present?
        end

        edges.each do |edge_attrs|
          source_id = resolve_node_id(edge_attrs[:source_node_id], edge_attrs[:source_node_temp_id], node_id_map)
          target_id = resolve_node_id(edge_attrs[:target_node_id], edge_attrs[:target_node_temp_id], node_id_map)

          prompt_flow.edges.create!(
            edge_attrs.except(:source_node_id, :target_node_id, :source_node_temp_id, :target_node_temp_id).merge(
              source_node_id: source_id,
              target_node_id: target_id
            )
          )
        end
      end

      def replace_nodes_and_edges!(prompt_flow, nodes, edges)
        prompt_flow.edges.destroy_all
        prompt_flow.nodes.destroy_all
        create_nodes_and_edges!(prompt_flow, nodes, edges)
      end

      def resolve_node_id(node_id, temp_id, node_id_map)
        return node_id if node_id.present?

        node_id_map[temp_id]
      end

      def flow_payload(prompt_flow)
        {
          prompt_flow: prompt_flow.as_json,
          nodes: prompt_flow.nodes.as_json,
          edges: prompt_flow.edges.as_json
        }
      end
    end
  end
end
