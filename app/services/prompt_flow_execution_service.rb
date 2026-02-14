# frozen_string_literal: true

class PromptFlowExecutionService
  class CycleDetectedError < StandardError; end
  class ExecutionLimitError < StandardError; end

  def initialize(prompt_flow)
    @prompt_flow = prompt_flow.is_a?(PromptFlow) ? prompt_flow : PromptFlow.find(prompt_flow)
  end

  def execute(inputs: {})
    execution = prompt_flow.executions.create!(
      status: 'running',
      inputs: inputs,
      outputs: {},
      execution_log: []
    )

    state = { outputs: {} }
    ordered_nodes = topological_sort

    run_nodes(ordered_nodes, inputs, state, execution)

    execution.update!(
      status: 'completed',
      outputs: state[:outputs],
      execution_log: execution.execution_log
    )

    execution
  rescue StandardError => e
    execution&.update!(
      status: 'failed',
      error_message: e.message,
      outputs: state ? state[:outputs] : {},
      execution_log: execution&.execution_log || []
    )
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

  def run_nodes(ordered_nodes, inputs, state, execution)
    executed_count = 0

    ordered_nodes.each do |node|
      executed_count += 1
      enforce_execution_limits!(executed_count)

      node_inputs = build_node_inputs(node, inputs, state)

      log_entry = {
        node_id: node.id,
        status: 'running',
        started_at: Time.current.iso8601
      }
      execution.execution_log << log_entry

      service = node_service_for(node)
      service.new(node: node, state: state, inputs: node_inputs).execute

      log_entry[:status] = 'completed'
      log_entry[:ended_at] = Time.current.iso8601
    rescue StandardError => e
      if log_entry
        log_entry[:status] = 'failed'
        log_entry[:ended_at] = Time.current.iso8601
        log_entry[:error] = e.message
      else
        execution.execution_log << {
          node_id: node.id,
          status: 'failed',
          started_at: Time.current.iso8601,
          ended_at: Time.current.iso8601,
          error: e.message
        }
      end
      raise
    ensure
      execution.update!(execution_log: execution.execution_log)
    end
  end

  def enforce_execution_limits!(executed_count)
    if executed_count > prompt_flow.max_executions
      raise ExecutionLimitError, 'max executions exceeded'
    end

    if executed_count > 200
      raise ExecutionLimitError, 'hard execution limit exceeded'
    end
  end

  def build_node_inputs(node, execution_inputs, state)
    return execution_inputs if node.node_type == 'input'

    inputs = {}
    prompt_flow.edges.each do |edge|
      next unless edge.target_node_id == node.id

      source_output = state[edge.source_node_id] || {}
      inputs[edge.target_port.to_s] = source_output[edge.source_port.to_s]
    end
    inputs
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
end
