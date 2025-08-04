# frozen_string_literal: true

FactoryBot.define do
  factory :prompt_version do
    association :prompt
    association :created_by, factory: :admin_user

    sequence(:version_number) { |n| n }
    content { "Extract information from the following text: %{text}" }
    name { prompt&.name || "test_prompt" }
    description { Faker::Lorem.sentence }
    category { 'knowledge_graph' }
    change_summary { 'Initial version' }
    is_current { false }  # Default to false to avoid conflicts
    metadata { {} }

    trait :historical do
      is_current { false }
      change_summary { 'Updated content' }
    end

    trait :current do
      is_current { true }
    end

    trait :version_2 do
      version_number { 2 }
      change_summary { 'Updated for better performance' }
    end

    trait :version_3 do
      version_number { 3 }
      change_summary { 'Added new parameters' }
    end

    trait :with_metadata do
      metadata do
        {
          'performance_notes' => 'Optimized for speed',
          'test_results' => 'All tests passing'
        }
      end
    end

    trait :major_change do
      change_summary { 'Major rewrite of prompt logic' }
      content { "Completely new approach: %{text} with %{new_parameter}" }
    end
  end
end
