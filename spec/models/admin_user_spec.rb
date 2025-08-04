# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminUser, type: :model do
  # Test data
  let(:valid_email) { 'test@example.com' }
  let(:invalid_email) { 'invalid_email' }
  let(:valid_password) { 'password123' }
  let(:short_password) { '123' }
  let(:duplicate_email) { 'duplicate@example.com' }

  subject { build(:admin_user) }

  it_behaves_like 'an ActiveRecord model'

  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:password) }
    it { should validate_length_of(:password).is_at_least(6) }

    context 'with valid attributes' do
      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'with invalid email' do
      it 'is invalid with malformed email' do
        subject.email = invalid_email
        expect(subject).not_to be_valid
        expect(subject.errors[:email]).to include('is invalid')
      end
    end

    context 'with duplicate email' do
      it 'is invalid' do
        create(:admin_user, email: duplicate_email)
        subject.email = duplicate_email
        expect(subject).not_to be_valid
        expect(subject.errors[:email]).to include('has already been taken')
      end
    end
  end

  describe 'associations' do
    it { should have_many(:created_prompts).class_name('Prompt').with_foreign_key('created_by_id') }
    it { should have_many(:updated_prompts).class_name('Prompt').with_foreign_key('updated_by_id') }
    it { should have_many(:prompt_versions).with_foreign_key('created_by_id') }
  end

  describe 'devise modules' do
    it 'includes database_authenticatable' do
      expect(AdminUser.devise_modules).to include(:database_authenticatable)
    end

    it 'includes recoverable' do
      expect(AdminUser.devise_modules).to include(:recoverable)
    end

    it 'includes rememberable' do
      expect(AdminUser.devise_modules).to include(:rememberable)
    end

    it 'includes validatable' do
      expect(AdminUser.devise_modules).to include(:validatable)
    end
  end

  describe 'constants' do
    it 'has DEFAULT_EMAIL constant' do
      expect(AdminUser::DEFAULT_EMAIL).to eq('admin@example.com')
    end
  end

  describe 'factory' do
    it 'creates valid admin user' do
      admin_user = create(:admin_user)
      expect(admin_user).to be_valid
      expect(admin_user).to be_persisted
    end

    it 'creates admin user with default email trait' do
      admin_user = create(:admin_user, :with_default_email)
      expect(admin_user.email).to eq(AdminUser::DEFAULT_EMAIL)
    end

    it 'creates admin user with custom password trait' do
      admin_user = create(:admin_user, :with_custom_password)
      expect(admin_user.valid_password?('custom_password_123')).to be true
    end
  end

  describe 'authentication' do
    let(:admin_user) { create(:admin_user, password: 'password123') }

    it 'authenticates with correct password' do
      expect(admin_user.valid_password?('password123')).to be true
    end

    it 'does not authenticate with incorrect password' do
      expect(admin_user.valid_password?('wrong_password')).to be false
    end
  end
end
