# frozen_string_literal: true

FactoryBot.define do
  factory :prompt_flow_execution do
    association :prompt_flow
    status { 'pending' }
    inputs { {} }
    outputs { {} }
    execution_log { [] }
    error_message { nil }
  end
end
