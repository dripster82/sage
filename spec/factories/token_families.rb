# frozen_string_literal: true

FactoryBot.define do
  factory :token_family do
    family_id { SecureRandom.uuid }
    latest_token_id { SecureRandom.uuid }
    version { 1 }
    device_fingerprint { Digest::SHA256.hexdigest("user-agent|language|screen|timezone") }
    association :admin_user

    trait :with_higher_version do
      version { 5 }
    end

    trait :with_custom_fingerprint do
      device_fingerprint { Digest::SHA256.hexdigest("custom-device-fingerprint") }
    end
  end
end
