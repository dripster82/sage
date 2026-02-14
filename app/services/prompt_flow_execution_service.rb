# frozen_string_literal: true

class PromptFlowExecutionService
  class CycleDetectedError < StandardError; end

  def initialize(prompt_flow)
    @prompt_flow = prompt_flow.is_a?(PromptFlow) ? prompt_flow : PromptFlow.find(prompt_flow)
  end

  def topological_sort
    nodes = @prompt_flow.nodes.to_a
    edges = @prompt_flow.edges.to_a

    in_degree = Hash.new(0)
    adjacency = Hash.new { |hash, key| hash[key] = [] }

    nodes.each { |node| in_degree[node.id] = 0 }

    edges.each do |edge|
      adjacency[edge.source_node_id] << edge.target_node_id
      in_degree[edge.target_node_id] += 1
    end

    queue = nodes.select { |node| in_degree[node.id].zero? }.map(&:id)
    ordered_ids = []

    until queue.empty?
      current = queue.shift
      ordered_ids << current

      adjacency[current].each do |neighbor|
        in_degree[neighbor] -= 1
        queue << neighbor if in_degree[neighbor].zero?
      end
    end

    if ordered_ids.size != nodes.size
      raise CycleDetectedError, 'cycle detected during topological sort'
    end

    ordered_ids.map { |id| nodes.find { |node| node.id == id } }
  end
end
