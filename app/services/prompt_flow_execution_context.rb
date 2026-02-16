# frozen_string_literal: true

class PromptFlowExecutionContext
  attr_reader :inputs, :node_outputs, :outputs

  def initialize(inputs: {})
    @inputs = stringify_keys(inputs)
    @node_outputs = {}
    @outputs = {}
  end

  def input_for(key)
    @inputs[key.to_s]
  end

  def set_node_output(node_id, output)
    @node_outputs[node_id] = stringify_keys(output || {})
  end

  def node_output(node_id)
    @node_outputs[node_id] || {}
  end

  def output_for(key)
    @outputs[key.to_s]
  end

  def set_output(key, value)
    @outputs[key.to_s] = value
  end

  def merge_outputs(hash)
    stringify_keys(hash || {}).each { |key, value| set_output(key, value) }
  end

  private

  def stringify_keys(hash)
    return {} unless hash.respond_to?(:to_h)

    hash.to_h.transform_keys(&:to_s)
  end
end
