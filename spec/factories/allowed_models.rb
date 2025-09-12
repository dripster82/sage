# frozen_string_literal: true

FactoryBot.define do
  factory :allowed_model do
    sequence(:name) { |n| "Test Model #{n}" }
    sequence(:model) { |n| "test/model-#{n}" }
    provider { 'test' }
    context_size { 128000 }
    active { true }
    default { false }

    trait :inactive do
      active { false }
    end

    trait :default do
      default { true }
    end

    trait :openai do
      name { 'GPT-4o' }
      model { 'openai/gpt-4o' }
      provider { 'openai' }
      context_size { 128000 }
    end

    trait :anthropic do
      name { 'Claude 3.5 Sonnet' }
      model { 'anthropic/claude-3.5-sonnet' }
      provider { 'anthropic' }
      context_size { 200000 }
    end

    trait :google do
      name { 'Gemini 2.5 Flash' }
      model { 'google/gemini-2.5-flash' }
      provider { 'google' }
      context_size { 1048576 }
    end

    trait :xai do
      name { 'Grok Code Fast 1' }
      model { 'x-ai/grok-code-fast-1' }
      provider { 'x-ai' }
      context_size { 256000 }
    end
  end
end
