# frozen_string_literal: true
require 'set'

class PromptFlowExecutionService
  class CycleDetectedError < StandardError; end
  class ExecutionLimitError < StandardError; end
  RuntimeNode = Struct.new(:id, :node_type, :prompt_id, :input_ports, :output_ports, :config, :prompt, keyword_init: true)
  RuntimeEdge = Struct.new(:id, :source_node_id, :target_node_id, :source_port, :target_port, keyword_init: true)

  def initialize(prompt_flow, graph: nil, persist_execution: true)
    @prompt_flow = prompt_flow.is_a?(PromptFlow) ? prompt_flow : PromptFlow.find(prompt_flow)
    @persist_execution = persist_execution
    @runtime_nodes, @runtime_edges = build_runtime_graph(graph) if graph.present?
  end

  def execute(inputs: {})
    flow_triggered_at = Time.current
    execution = if @persist_execution && prompt_flow.persisted?
                  prompt_flow.executions.create!(
                    status: 'running',
                    inputs: inputs,
                    outputs: {},
                    execution_log: []
                  )
                else
                  PromptFlowExecution.new(status: 'running', inputs: inputs, outputs: {}, execution_log: [])
                end

    context = PromptFlowExecutionContext.new(inputs: inputs)
    @execution = execution
    @context = context
    @executed_nodes = Set.new
    @active_nodes = Set.new
    @executed_count = 0
    @nodes_by_id = execution_nodes.index_by(&:id)
    @edges = execution_edges
    @incoming_var_edges = build_incoming_var_edges
    @outgoing_flow_edges = build_outgoing_flow_edges

    @execution.execution_log << {
      node_id: 'start',
      node_type: 'start',
      node_name: 'Start',
      status: 'completed',
      started_at: flow_triggered_at.iso8601,
      ended_at: flow_triggered_at.iso8601
    }

    flow_root_nodes.each { |node| execute_node(node) }
    output_nodes.each { |node| execute_node(node) }

    execution.update!(
      status: 'completed',
      outputs: context.outputs,
      execution_log: execution.execution_log
    ) if execution.persisted?
    execution.status = 'completed'
    execution.outputs = context.outputs

    execution
  rescue ExecutionLimitError => e
    partial_outputs = partial_outputs_from_context(context)
    if execution&.persisted?
      execution.update!(
        status: 'failed',
        error_message: e.message,
        outputs: partial_outputs,
        execution_log: execution&.execution_log || []
      )
    end
    if execution
      execution.status = 'failed'
      execution.error_message = e.message
      execution.outputs = partial_outputs
    end
    raise
  rescue StandardError => e
    if execution&.persisted?
      execution.update!(
        status: 'failed',
        error_message: e.message,
        outputs: context ? context.outputs : {},
        execution_log: execution&.execution_log || []
      )
    end
    if execution
      execution.status = 'failed'
      execution.error_message = e.message
      execution.outputs = context ? context.outputs : {}
    end
    raise
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

  private

  attr_reader :prompt_flow

  def execute_node(node)
    return if @executed_nodes.include?(node.id)
    raise CycleDetectedError, "cycle detected while executing node #{node.id}" if @active_nodes.include?(node.id)

    @active_nodes.add(node.id)
    resolve_dependencies_for(node)

    @executed_count += 1
    enforce_execution_limits!(@executed_count)

    log_entry = {
      node_id: node.id,
      node_type: node.node_type,
      node_name: node_display_name(node),
      status: 'running',
      started_at: Time.current.iso8601
    }
    @execution.execution_log << log_entry

    node_inputs = build_node_inputs(node)
    service_state = { outputs: context.outputs }
    result = node_service_for(node).new(node: node, state: service_state, inputs: node_inputs).execute
    context.set_node_output(node.id, result)
    context.merge_outputs(service_state[:outputs])
    attach_prompt_metrics(log_entry, result)

    log_entry[:status] = 'completed'
    log_entry[:ended_at] = Time.current.iso8601
    @executed_nodes.add(node.id)
    flow_successors_for(node).each { |successor| execute_node(successor) }
  rescue StandardError => e
    if log_entry
      log_entry[:status] = 'failed'
      log_entry[:ended_at] = Time.current.iso8601
      log_entry[:error] = e.message
    end
    raise
  ensure
    @active_nodes.delete(node.id)
    @execution.update!(execution_log: @execution.execution_log) if @execution&.persisted?
  end

  def enforce_execution_limits!(executed_count)
    if executed_count > prompt_flow.max_executions
      raise ExecutionLimitError, 'max executions exceeded'
    end

    if executed_count > 200
      raise ExecutionLimitError, 'hard execution limit exceeded'
    end
  end

  def resolve_dependencies_for(node)
    required_ports = port_keys(node.input_ports)
    return if required_ports.empty?

    required_ports.each do |port|
      next if port.to_s == 'flow'
      next if build_node_inputs(node)[port.to_s].present?

      source_edges = @incoming_var_edges[[node.id, port.to_s]] || []
      raise ArgumentError, "missing required input '#{port}' for node #{node.id}" if source_edges.empty?

      source_edges.each do |edge|
        source_node = @nodes_by_id[edge.source_node_id]
        next unless source_node

        execute_node(source_node)
      end
    end
  end

  def build_node_inputs(node)
    return context.inputs if node.node_type == 'input'

    inputs = {}
    @edges.each do |edge|
      next unless edge.target_node_id == node.id
      next if edge.target_port.to_s == 'flow'

      source_output = context.node_output(edge.source_node_id)
      inputs[edge.target_port.to_s] = source_output[edge.source_port.to_s]
    end

    inputs
  end

  def flow_root_nodes
    candidates = @nodes_by_id.values.reject { |node| node.node_type == 'input' }
    return candidates if candidates.empty?

    incoming_flow_counts = Hash.new(0)
    @edges.each do |edge|
      next unless edge.source_port.to_s == 'flow' && edge.target_port.to_s == 'flow'

      incoming_flow_counts[edge.target_node_id] += 1
    end

    roots = candidates.select { |node| incoming_flow_counts[node.id].zero? }
    roots.presence || candidates
  end

  def flow_successors_for(node)
    ids = @outgoing_flow_edges[node.id] || []
    ids.map { |id| @nodes_by_id[id] }.compact
  end

  def output_nodes
    @nodes_by_id.values.select { |node| node.node_type == 'output' }
  end

  def build_incoming_var_edges
    index = Hash.new { |hash, key| hash[key] = [] }
    @edges.each do |edge|
      next if edge.target_port.to_s == 'flow'

      index[[edge.target_node_id, edge.target_port.to_s]] << edge
    end
    index
  end

  def build_outgoing_flow_edges
    index = Hash.new { |hash, key| hash[key] = [] }
    @edges.each do |edge|
      next unless edge.source_port.to_s == 'flow' && edge.target_port.to_s == 'flow'

      index[edge.source_node_id] << edge.target_node_id
    end
    index
  end

  def partial_outputs_from_context(state)
    outputs = state ? (state.outputs || {}).dup : {}
    return outputs if outputs.present?

    output_nodes.each do |node|
      node_result = state.node_output(node.id)
      if node_result.present?
        outputs.merge!(node_result)
        next
      end

      incoming = @edges.select do |edge|
        edge.target_node_id == node.id && edge.target_port.to_s != 'flow'
      end
      incoming.each do |edge|
        source_result = state.node_output(edge.source_node_id)
        value = source_result[edge.source_port.to_s]
        outputs[edge.target_port.to_s] = value if value.present?
      end
    end

    outputs
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

  def node_service_for(node)
    case node.node_type
    when 'input'
      PromptFlowServices::InputNodeService
    when 'prompt'
      PromptFlowServices::PromptNodeService
    when 'output'
      PromptFlowServices::OutputNodeService
    else
      raise ArgumentError, "unknown node type: #{node.node_type}"
    end
  end

  def context
    @context
  end

  def node_display_name(node)
    case node.node_type
    when 'input'
      key = node.config.is_a?(Hash) ? (node.config['param_key'] || node.config[:param_key]) : nil
      "Input (#{key.presence || 'unset'})"
    when 'prompt'
      "Prompt (#{node.prompt&.name || "id:#{node.prompt_id}"})"
    when 'output'
      'Output'
    when 'start'
      'Start'
    else
      node.node_type.to_s.humanize
    end
  end

  def attach_prompt_metrics(log_entry, node_result)
    return unless node_result.is_a?(Hash)

    metrics = node_result['_prompt_metrics'] || node_result[:_prompt_metrics]
    return unless metrics.is_a?(Hash)

    log_entry[:prompt_metrics] = {
      ai_log_id: metrics['ai_log_id'] || metrics[:ai_log_id],
      input_tokens: (metrics['input_tokens'] || metrics[:input_tokens]).to_i,
      output_tokens: (metrics['output_tokens'] || metrics[:output_tokens]).to_i,
      total_cost: (metrics['total_cost'] || metrics[:total_cost]).to_f
    }
  end

  def execution_nodes
    @runtime_nodes || prompt_flow.nodes.to_a
  end

  def execution_edges
    @runtime_edges || prompt_flow.edges.to_a
  end

  def build_runtime_graph(graph)
    graph = if graph.is_a?(String)
              JSON.parse(graph)
            else
              graph
            end
    nodes_data = Array(graph['nodes'] || graph[:nodes])
    edges_data = Array(graph['edges'] || graph[:edges])
    prompt_ids = nodes_data.filter_map { |n| n['prompt_id'] || n[:prompt_id] }.uniq
    prompts_by_id = Prompt.where(id: prompt_ids).index_by(&:id)

    node_id_map = {}
    runtime_nodes = []
    next_id = 1
    nodes_data.each do |node_data|
      node_type = (node_data['node_type'] || node_data[:node_type]).to_s
      next if node_type == 'start'

      original_id = (node_data['id'] || node_data[:id]).to_s
      runtime_id = next_id
      next_id += 1
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
        source_node_id: source_id,
        target_node_id: target_id,
        source_port: edge_data['source_port'] || edge_data[:source_port],
        target_port: edge_data['target_port'] || edge_data[:target_port]
      )
    end

    [runtime_nodes, runtime_edges]
  rescue JSON::ParserError
    [[], []]
  end
end
