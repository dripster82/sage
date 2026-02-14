# frozen_string_literal: true

class PromptFlowEdge < ApplicationRecord
  belongs_to :prompt_flow
  belongs_to :source_node, class_name: 'PromptFlowNode'
  belongs_to :target_node, class_name: 'PromptFlowNode'

  validates :source_port, presence: true
  validates :target_port, presence: true

  validate :no_self_edge
  validate :nodes_in_same_flow

  private

  def no_self_edge
    return if source_node_id.blank? || target_node_id.blank?

    errors.add(:target_node_id, 'cannot be the same as source node') if source_node_id == target_node_id
  end

  def nodes_in_same_flow
    return if source_node.blank? || target_node.blank? || prompt_flow_id.blank?

    if source_node.prompt_flow_id != prompt_flow_id || target_node.prompt_flow_id != prompt_flow_id
      errors.add(:base, 'source and target nodes must belong to the same prompt flow')
    end
  end
end
