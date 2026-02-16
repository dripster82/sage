# frozen_string_literal: true

class PromptFlow < ApplicationRecord
  STATUSES = %w[draft valid invalid].freeze

  belongs_to :created_by, class_name: 'AdminUser'
  belongs_to :updated_by, class_name: 'AdminUser'

  has_many :edges, class_name: 'PromptFlowEdge', dependent: :destroy
  has_many :nodes, class_name: 'PromptFlowNode', dependent: :destroy
  has_many :executions, class_name: 'PromptFlowExecution', dependent: :destroy

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :version_number, numericality: { greater_than: 0 }
  validates :version_number, uniqueness: { scope: :name }
  validates :max_executions, numericality: { greater_than: 0 }

  scope :for_name, ->(name) { where(name: name) }
  scope :current, -> { where(is_current: true) }
  scope :recent_first, -> { order(version_number: :desc) }

  def versions
    self.class.for_name(name).recent_first
  end

  def next_version_number
    self.class.for_name(name).maximum(:version_number).to_i + 1
  end

  def duplicate_as_draft!(admin_user)
    self.class.transaction do
      new_flow = dup
      new_flow.is_current = false
      new_flow.status = 'draft'
      new_flow.version_number = next_version_number
      new_flow.created_by = admin_user
      new_flow.updated_by = admin_user
      new_flow.save!
      new_flow.update!(graph_json: graph_json)
      new_flow
    end
  end

  def sync_graph_to_nodes_and_edges!(graph_source = graph_json)
    graph = graph_source || {}
    if graph.is_a?(String)
      begin
        graph = JSON.parse(graph)
      rescue JSON::ParserError
        graph = {}
      end
    end

    nodes_data = graph['nodes'] || graph[:nodes] || []
    edges_data = graph['edges'] || graph[:edges] || []
    nodes_data = [] unless nodes_data.is_a?(Array)
    edges_data = [] unless edges_data.is_a?(Array)

    transaction do
      edges.destroy_all
      nodes.destroy_all

      node_id_map = {}
      nodes_data.each do |node_data|
        node_type = node_data['node_type'] || node_data[:node_type]
        next if node_type.to_s == 'start'

        node = nodes.create!(
          node_type: node_type,
          prompt_id: node_data['prompt_id'] || node_data[:prompt_id],
          position_x: node_data['position_x'] || node_data[:position_x],
          position_y: node_data['position_y'] || node_data[:position_y],
          input_ports: node_data['input_ports'] || node_data[:input_ports] || {},
          output_ports: node_data['output_ports'] || node_data[:output_ports] || {},
          config: node_data['config'] || node_data[:config] || {}
        )
        node_id_map[(node_data['id'] || node_data[:id]).to_s] = node.id
      end

      edges_data.each do |edge_data|
        source_key = (edge_data['source_node_id'] || edge_data[:source_node_id]).to_s
        target_key = (edge_data['target_node_id'] || edge_data[:target_node_id]).to_s
        source_id = node_id_map[source_key]
        target_id = node_id_map[target_key]
        next unless source_id && target_id

        edges.create!(
          source_node_id: source_id,
          target_node_id: target_id,
          source_port: edge_data['source_port'] || edge_data[:source_port],
          target_port: edge_data['target_port'] || edge_data[:target_port]
        )
      end
    end
  end
end
