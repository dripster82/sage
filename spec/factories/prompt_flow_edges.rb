# frozen_string_literal: true

FactoryBot.define do
  factory :prompt_flow_edge do
    association :prompt_flow
    source_port { 'output' }
    target_port { 'input' }
    validation_status { 'valid' }

    after(:build) do |edge|
      edge.source_node ||= build(:prompt_flow_node, prompt_flow: edge.prompt_flow)
      edge.target_node ||= build(:prompt_flow_node, :output_node, prompt_flow: edge.prompt_flow)
    end
  end
end
