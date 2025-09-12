# frozen_string_literal: true

FactoryBot.define do
  factory :prompt do
    sequence(:name) { |n| "test_prompt_#{n}" }
    content { "Extract information from the following text: %{text}" }
    description { Faker::Lorem.sentence }
    category { 'knowledge_graph' }
    status { 'active' }
    current_version { 1 }
    tags { ['text'].to_json }
    metadata { {} }
    
    association :created_by, factory: :admin_user
    association :updated_by, factory: :admin_user

    trait :inactive do
      status { 'inactive' }
    end

    trait :draft do
      status { 'draft' }
    end

    trait :with_multiple_tags do
      content { "Process %{text} with %{schema} and %{summary}" }
      tags { ['text', 'schema', 'summary'].to_json }
    end

    trait :text_summarization do
      name { 'text_summarization' }
      content { "Summarize the following text: %{text}" }
      category { 'summarization' }
    end

    trait :kg_extraction do
      name { 'kg_extraction_1st_pass' }
      content { "Extract entities from: %{text} using schema: %{current_schema}" }
      category { 'knowledge_graph' }
    end

    trait :with_metadata do
      metadata do
        {
          'version' => '1.0',
          'author' => 'system',
          'purpose' => 'testing'
        }
      end
    end

    trait :with_model do
      association :allowed_model, factory: :allowed_model
    end

    trait :with_openai_model do
      association :allowed_model, factory: [:allowed_model, :openai]
    end

    trait :with_anthropic_model do
      association :allowed_model, factory: [:allowed_model, :anthropic]
    end

    # Create associated prompt version after creation
    after(:create) do |prompt|
      # The prompt model automatically creates the first version via callback
      # So we don't need to explicitly create it here
    end
  end
end
