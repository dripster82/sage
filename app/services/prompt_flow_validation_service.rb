# frozen_string_literal: true

class PromptFlowValidationService
  RuntimeNode = Struct.new(:id, :node_type, :prompt_id, :input_ports, :output_ports, :config, :prompt, keyword_init: true)
  RuntimeEdge = Struct.new(:id, :prompt_flow_id, :source_node_id, :target_node_id, :source_port, :target_port, keyword_init: true)

  def initialize(prompt_flow, graph: nil)
    @prompt_flow = prompt_flow.is_a?(PromptFlow) ? prompt_flow : PromptFlow.find(prompt_flow)
    @graph = normalize_graph(graph)
    @prompt_nodes, @prompt_edges = build_runtime_graph(@graph) if @graph.present?
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

  def prompt_nodes
    @prompt_nodes || prompt_flow.nodes.to_a
  end

  def prompt_edges
    @prompt_edges || prompt_flow.edges.to_a
  end

  def nodes_by_id
    @nodes_by_id ||= prompt_nodes.index_by(&:id)
  end

  def validate_edge_nodes(errors)
    prompt_edges.each do |edge|
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
    prompt_edges.each do |edge|
      source = nodes_by_id[edge.source_node_id]
      target = nodes_by_id[edge.target_node_id]
      next if source.nil? || target.nil?

      source_ports = allowed_source_ports(source)
      target_ports = allowed_target_ports(target)

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

  def allowed_source_ports(node)
    ports = port_keys(node.output_ports)
    ports << 'flow' if %w[prompt].include?(node.node_type)
    ports.uniq
  end

  def allowed_target_ports(node)
    ports = port_keys(node.input_ports)
    ports << 'flow' if %w[prompt output].include?(node.node_type)
    ports.uniq
  end

  def validate_required_inputs(errors)
    prompt_nodes.each do |node|
      required_ports = required_input_ports(node.input_ports)
      next if required_ports.empty?

      required_ports.each do |port|
        connected = prompt_edges.any? do |edge|
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
    prompt_edges.each do |edge|
      next if nodes_by_id[edge.source_node_id].nil? || nodes_by_id[edge.target_node_id].nil?

      adjacency[edge.source_node_id] << edge.target_node_id
    end

    visited = {}
    stack = {}
    cycle_path = nil

    prompt_nodes.each do |node|
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

  def normalize_graph(graph)
    return nil if graph.blank?
    return graph if graph.is_a?(Hash)

    JSON.parse(graph)
  rescue JSON::ParserError
    nil
  end

  def build_runtime_graph(graph)
    nodes_data = Array(graph['nodes'] || graph[:nodes])
    edges_data = Array(graph['edges'] || graph[:edges])
    prompt_ids = nodes_data.filter_map { |n| n['prompt_id'] || n[:prompt_id] }.uniq
    prompts_by_id = Prompt.where(id: prompt_ids).index_by(&:id)

    node_id_map = {}
    runtime_nodes = []
    nodes_data.each_with_index do |node_data, idx|
      node_type = (node_data['node_type'] || node_data[:node_type]).to_s
      next if node_type == 'start'

      original_id = (node_data['id'] || node_data[:id]).to_s
      runtime_id = idx + 1
      node_id_map[original_id] = runtime_id
      prompt_id = node_data['prompt_id'] || node_data[:prompt_id]
      runtime_nodes << RuntimeNode.new(
        id: runtime_id,
        node_type: node_type,
        prompt_id: prompt_id,
        input_ports: node_data['input_ports'] || node_data[:input_ports] || {},
        output_ports: node_data['output_ports'] || node_data[:output_ports] || {},
        config: node_data['config'] || node_data[:config] || {},
        prompt: prompts_by_id[prompt_id]
      )
    end

    runtime_edges = []
    edges_data.each_with_index do |edge_data, idx|
      source_id = node_id_map[(edge_data['source_node_id'] || edge_data[:source_node_id]).to_s]
      target_id = node_id_map[(edge_data['target_node_id'] || edge_data[:target_node_id]).to_s]
      next unless source_id && target_id

      runtime_edges << RuntimeEdge.new(
        id: idx + 1,
        prompt_flow_id: prompt_flow.id,
        source_node_id: source_id,
        target_node_id: target_id,
        source_port: edge_data['source_port'] || edge_data[:source_port],
        target_port: edge_data['target_port'] || edge_data[:target_port]
      )
    end

    [runtime_nodes, runtime_edges]
  end
end
