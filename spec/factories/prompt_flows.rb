# frozen_string_literal: true

FactoryBot.define do
  factory :prompt_flow do
    sequence(:name) { |n| "prompt_flow_#{n}" }
    description { Faker::Lorem.sentence }
    status { 'draft' }
    version_number { 1 }
    is_current { true }
    max_executions { 20 }
    graph_json { {} }

    association :created_by, factory: :admin_user
    association :updated_by, factory: :admin_user
  end
end
