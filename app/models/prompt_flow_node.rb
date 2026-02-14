# frozen_string_literal: true

class PromptFlowNode < ApplicationRecord
  NODE_TYPES = %w[input prompt output].freeze

  belongs_to :prompt_flow
  belongs_to :prompt, optional: true

  validates :node_type, inclusion: { in: NODE_TYPES }

  validate :prompt_required_for_prompt_node

  private

  def prompt_required_for_prompt_node
    return unless node_type == 'prompt'

    errors.add(:prompt_id, 'must be present for prompt nodes') if prompt_id.blank?
  end
end
