# frozen_string_literal: true

FactoryBot.define do
  factory :admin_user do
    email { Faker::Internet.unique.email }
    password { 'password123' }
    password_confirmation { 'password123' }

    trait :with_default_email do
      email { AdminUser::DEFAULT_EMAIL }
    end

    trait :with_custom_password do
      password { 'custom_password_123' }
      password_confirmation { 'custom_password_123' }
    end
  end
end
