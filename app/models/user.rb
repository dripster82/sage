# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :credits, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Associations
  has_many :token_families, dependent: :destroy

  # Instance methods
  def has_sufficient_credits?(amount)
    credits >= amount
  end

  def deduct_credits!(amount)
    raise "Insufficient credits" unless has_sufficient_credits?(amount)
    update!(credits: credits - amount)
  end

  def add_credits!(amount)
    update!(credits: credits + amount)
  end

  def update_last_seen!
    update!(last_seen: Time.current)
  end
end
