# frozen_string_literal: true

class PromptFlowValidationService
  def initialize(prompt_flow)
    @prompt_flow = prompt_flow.is_a?(PromptFlow) ? prompt_flow : PromptFlow.find(prompt_flow)
  end

  def call
    errors = []

    validate_edge_nodes(errors)
    validate_ports(errors)
    validate_required_inputs(errors)
    validate_cycles(errors)

    errors
  end

  private

  attr_reader :prompt_flow

  def nodes_by_id
    @nodes_by_id ||= prompt_flow.nodes.index_by(&:id)
  end

  def validate_edge_nodes(errors)
    prompt_flow.edges.each do |edge|
      unless edge.prompt_flow_id == prompt_flow.id
        errors << error_hash(:edge_flow_mismatch, 'edge does not belong to prompt flow', edge_id: edge.id)
      end

      source = nodes_by_id[edge.source_node_id]
      target = nodes_by_id[edge.target_node_id]

      errors << error_hash(:edge_missing_node, 'edge source node is missing', edge_id: edge.id) if source.nil?
      errors << error_hash(:edge_missing_node, 'edge target node is missing', edge_id: edge.id) if target.nil?
    end
  end

  def validate_ports(errors)
    prompt_flow.edges.each do |edge|
      source = nodes_by_id[edge.source_node_id]
      target = nodes_by_id[edge.target_node_id]
      next if source.nil? || target.nil?

      source_ports = port_keys(source.output_ports)
      target_ports = port_keys(target.input_ports)

      unless source_ports.include?(edge.source_port.to_s)
        errors << error_hash(
          :port_missing_on_node,
          'edge source port not found on source node',
          edge_id: edge.id,
          node_id: source.id,
          port: edge.source_port
        )
      end

      unless target_ports.include?(edge.target_port.to_s)
        errors << error_hash(
          :port_missing_on_node,
          'edge target port not found on target node',
          edge_id: edge.id,
          node_id: target.id,
          port: edge.target_port
        )
      end
    end
  end

  def validate_required_inputs(errors)
    prompt_flow.nodes.each do |node|
      required_ports = required_input_ports(node.input_ports)
      next if required_ports.empty?

      required_ports.each do |port|
        connected = prompt_flow.edges.any? do |edge|
          edge.target_node_id == node.id && edge.target_port.to_s == port
        end

        next if connected

        errors << error_hash(
          :required_input_missing,
          'required input port is not connected',
          node_id: node.id,
          port: port
        )
      end
    end
  end

  def validate_cycles(errors)
    adjacency = Hash.new { |hash, key| hash[key] = [] }
    prompt_flow.edges.each do |edge|
      next if nodes_by_id[edge.source_node_id].nil? || nodes_by_id[edge.target_node_id].nil?

      adjacency[edge.source_node_id] << edge.target_node_id
    end

    visited = {}
    stack = {}
    cycle_path = nil

    prompt_flow.nodes.each do |node|
      next if visited[node.id]

      cycle_path = find_cycle(node.id, adjacency, visited, stack, [])
      break if cycle_path
    end

    return unless cycle_path

    errors << error_hash(
      :cycle_detected,
      'cycle detected in prompt flow',
      node_ids: cycle_path
    )
  end

  def find_cycle(node_id, adjacency, visited, stack, path)
    visited[node_id] = true
    stack[node_id] = true
    path << node_id

    adjacency[node_id].each do |neighbor|
      if !visited[neighbor]
        cycle = find_cycle(neighbor, adjacency, visited, stack, path)
        return cycle if cycle
      elsif stack[neighbor]
        cycle_start = path.index(neighbor) || 0
        return path[cycle_start..] + [neighbor]
      end
    end

    stack.delete(node_id)
    path.pop
    nil
  end

  def port_keys(ports)
    case ports
    when Hash
      ports.keys.map(&:to_s)
    when Array
      ports.map(&:to_s)
    when String
      [ports]
    else
      []
    end
  end

  def required_input_ports(ports)
    case ports
    when Hash
      ports.filter_map do |key, value|
        required = value.is_a?(Hash) ? value['required'] || value[:required] : false
        key.to_s if required
      end
    when Array
      ports.map(&:to_s)
    when String
      [ports]
    else
      []
    end
  end

  def error_hash(type, message, data = {})
    { type: type, message: message, data: data }
  end
end
