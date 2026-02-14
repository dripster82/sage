# frozen_string_literal: true

class PromptFlowExecution < ApplicationRecord
  STATUSES = %w[pending running completed failed].freeze

  belongs_to :prompt_flow

  validates :status, inclusion: { in: STATUSES }
end
