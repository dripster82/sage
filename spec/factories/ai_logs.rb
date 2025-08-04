# frozen_string_literal: true

FactoryBot.define do
  factory :ai_log do
    model { 'google/gemini-2.0-flash-001' }
    query { Faker::Lorem.paragraph }
    response { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    settings do
      {
        'temperature' => 0.7,
        'max_tokens' => 1000,
        'top_p' => 0.9
      }
    end
    input_tokens { rand(50..500) }
    output_tokens { rand(100..800) }
    session_uuid { SecureRandom.uuid }
    chat_id { nil }

    trait :with_chat do
      chat_id { SecureRandom.uuid }
    end

    trait :with_high_tokens do
      input_tokens { rand(1000..2000) }
      output_tokens { rand(1500..3000) }
    end

    trait :with_error do
      response { nil }
    end

    trait :recent do
      created_at { 1.hour.ago }
    end

    trait :old do
      created_at { 1.month.ago }
    end

    trait :anthropic_model do
      model { 'anthropic/claude-3.5-haiku' }
    end

    trait :openai_model do
      model { 'openai/gpt-4' }
    end
  end
end
