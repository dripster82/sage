# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TokenFamily, type: :model do
  let(:admin_user) { create(:admin_user) }
  let(:family_id) { SecureRandom.uuid }
  let(:token_id) { SecureRandom.uuid }
  let(:device_fingerprint) { 'hashed-device-fingerprint' }

  subject do
    build(:token_family,
          family_id: family_id,
          admin_user: admin_user,
          latest_token_id: token_id,
          version: 1,
          device_fingerprint: device_fingerprint)
  end

  it_behaves_like 'an ActiveRecord model'

  describe 'validations' do
    it { should validate_presence_of(:family_id) }
    it { should validate_presence_of(:latest_token_id) }
    it { should validate_presence_of(:version) }
    it { should validate_presence_of(:device_fingerprint) }
    it { should validate_uniqueness_of(:family_id) }
    it { should validate_numericality_of(:version).is_greater_than(0) }

    context 'with valid attributes' do
      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'with invalid family_id' do
      it 'is invalid with blank family_id' do
        subject.family_id = ''
        expect(subject).not_to be_valid
        expect(subject.errors[:family_id]).to include("can't be blank")
      end
    end

    context 'with invalid version' do
      it 'is invalid with zero version' do
        subject.version = 0
        expect(subject).not_to be_valid
        expect(subject.errors[:version]).to include('must be greater than 0')
      end

      it 'is invalid with negative version' do
        subject.version = -1
        expect(subject).not_to be_valid
        expect(subject.errors[:version]).to include('must be greater than 0')
      end
    end
  end

  describe 'associations' do
    it { should belong_to(:admin_user) }
  end

  describe 'indexes' do
    it 'has index on family_id' do
      expect(ActiveRecord::Base.connection.index_exists?(:token_families, :family_id)).to be true
    end

    it 'has index on admin_user_id' do
      expect(ActiveRecord::Base.connection.index_exists?(:token_families, :admin_user_id)).to be true
    end
  end

  describe 'instance methods' do
    let(:token_family) { create(:token_family, admin_user: admin_user, version: 3) }

    describe '#increment_version!' do
      it 'increments the version by 1' do
        expect { token_family.increment_version! }.to change { token_family.version }.by(1)
      end

      it 'saves the record' do
        token_family.increment_version!
        expect(token_family.reload.version).to eq(4)
      end
    end

    describe '#update_token!' do
      let(:new_token_id) { SecureRandom.uuid }

      it 'updates the latest_token_id and increments version' do
        expect {
          token_family.update_token!(new_token_id)
        }.to change { token_family.latest_token_id }.to(new_token_id)
         .and change { token_family.version }.by(1)
      end

      it 'saves the record' do
        token_family.update_token!(new_token_id)
        reloaded = token_family.reload
        expect(reloaded.latest_token_id).to eq(new_token_id)
        expect(reloaded.version).to eq(4)
      end
    end
  end

  describe 'class methods' do
    describe '.find_by_family_id' do
      let!(:token_family) { create(:token_family, family_id: family_id) }

      it 'finds token family by family_id' do
        result = TokenFamily.find_by_family_id(family_id)
        expect(result).to eq(token_family)
      end

      it 'returns nil for non-existent family_id' do
        result = TokenFamily.find_by_family_id('non-existent')
        expect(result).to be_nil
      end
    end

    describe '.delete_all_for_user' do
      let!(:user_families) { create_list(:token_family, 3, admin_user: admin_user) }
      let!(:other_user_families) { create_list(:token_family, 2, admin_user: create(:admin_user)) }

      it 'deletes all token families for a specific user' do
        expect {
          TokenFamily.delete_all_for_user(admin_user.id)
        }.to change { TokenFamily.count }.by(-3)
      end

      it 'does not delete token families for other users' do
        TokenFamily.delete_all_for_user(admin_user.id)
        expect(TokenFamily.where(admin_user: admin_user)).to be_empty
        expect(TokenFamily.count).to eq(2)
      end

      it 'returns the count of deleted records' do
        count = TokenFamily.delete_all_for_user(admin_user.id)
        expect(count).to eq(3)
      end
    end
  end
end
