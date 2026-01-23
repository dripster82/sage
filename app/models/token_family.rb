# frozen_string_literal: true

class TokenFamily < ApplicationRecord
  # Associations
  belongs_to :admin_user, optional: true
  belongs_to :user, optional: true

  # Validations
  validates :family_id, presence: true, uniqueness: true
  validates :latest_token_id, presence: true
  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :device_fingerprint, presence: true
  validate :either_admin_user_or_user

  # Class methods
  def self.find_by_family_id(family_id)
    find_by(family_id: family_id)
  end

  def self.delete_all_for_user(user_id, user_type = :admin_user)
    if user_type == :user
      where(user_id: user_id).delete_all
    else
      where(admin_user_id: user_id).delete_all
    end
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

  private

  def either_admin_user_or_user
    if admin_user_id.blank? && user_id.blank?
      errors.add(:base, "Either admin_user or user must be present")
    elsif admin_user_id.present? && user_id.present?
      errors.add(:base, "Cannot have both admin_user and user")
    end
  end
end
