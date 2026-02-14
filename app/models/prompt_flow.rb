# frozen_string_literal: true

class PromptFlow < ApplicationRecord
  STATUSES = %w[draft valid invalid].freeze

  belongs_to :created_by, class_name: 'AdminUser'
  belongs_to :updated_by, class_name: 'AdminUser'

  has_many :edges, class_name: 'PromptFlowEdge', dependent: :destroy
  has_many :nodes, class_name: 'PromptFlowNode', dependent: :destroy
  has_many :executions, class_name: 'PromptFlowExecution', dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :version_number, numericality: { greater_than: 0 }
  validates :max_executions, numericality: { greater_than: 0 }
end
