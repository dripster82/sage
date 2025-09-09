# frozen_string_literal: true

class TokenFamily < ApplicationRecord
  # Associations
  belongs_to :admin_user

  # Validations
  validates :family_id, presence: true, uniqueness: true
  validates :latest_token_id, presence: true
  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :device_fingerprint, presence: true

  # Class methods
  def self.find_by_family_id(family_id)
    find_by(family_id: family_id)
  end

  def self.delete_all_for_user(admin_user_id)
    where(admin_user_id: admin_user_id).delete_all
  end

  # Instance methods
  def increment_version!
    self.version += 1
    save!
  end

  def update_token!(new_token_id)
    self.latest_token_id = new_token_id
    self.version += 1
    save!
  end
end
