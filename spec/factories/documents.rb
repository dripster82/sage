# frozen_string_literal: true

# Note: Document is an ActiveModel, not ActiveRecord, so we use build instead of create
FactoryBot.define do
  factory :document, class: 'Document' do
    file_path { 'spec/fixtures/test_document.txt' }
    text { Faker::Lorem.paragraphs(number: 5).join("\n\n") }
    summary { Faker::Lorem.paragraph }
    vector { Array.new(1536) { rand(-1.0..1.0) } }
    chunks { build_list(:chunk, 3) }

    # Don't use ActiveRecord callbacks since this is ActiveModel
    skip_create
    initialize_with { new(attributes) }

    trait :pdf_document do
      file_path { 'spec/fixtures/test_document.pdf' }
    end

    trait :txt_document do
      file_path { 'spec/fixtures/test_document.txt' }
    end

    trait :long_document do
      text { Faker::Lorem.paragraphs(number: 20).join("\n\n") }
      chunks { build_list(:chunk, 10) }
    end

    trait :short_document do
      text { Faker::Lorem.paragraph }
      chunks { build_list(:chunk, 1) }
    end

    trait :without_summary do
      summary { nil }
    end

    trait :without_vector do
      vector { nil }
    end

    trait :without_chunks do
      chunks { [] }
    end

    trait :with_chunks do
      chunks { build_list(:chunk, 5) }
    end
  end
end
