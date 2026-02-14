# frozen_string_literal: true

FactoryBot.define do
  factory :prompt_flow_node do
    association :prompt_flow
    node_type { 'input' }
    prompt { nil }
    position_x { 100 }
    position_y { 200 }
    config { {} }
    input_ports { {} }
    output_ports { {} }

    trait :prompt_node do
      node_type { 'prompt' }
      association :prompt, factory: :prompt
    end

    trait :output_node do
      node_type { 'output' }
    end
  end
end
