# frozen_string_literal: true

# Note: Chunk is an ActiveModel, not ActiveRecord, so we use build instead of create
FactoryBot.define do
  factory :chunk, class: 'Chunk' do
    text { Faker::Lorem.paragraph }
    file_path { 'spec/fixtures/test_document.txt' }
    position { 0 }
    vector { Array.new(1536) { rand(-1.0..1.0) } }

    # Don't use ActiveRecord callbacks since this is ActiveModel
    skip_create
    initialize_with { new(attributes) }

    trait :first_chunk do
      position { 0 }
    end

    trait :middle_chunk do
      position { 1 }
    end

    trait :last_chunk do
      position { 2 }
    end

    trait :long_text do
      text { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    end

    trait :short_text do
      text { Faker::Lorem.sentence }
    end

    trait :without_vector do
      vector { nil }
    end

    trait :pdf_chunk do
      file_path { 'spec/fixtures/test_document.pdf' }
    end

    trait :with_sequence do
      sequence(:position) { |n| n }
    end
  end
end
