# frozen_string_literal: true

class AdminUser < ApplicationRecord
  DEFAULT_EMAIL = "admin@example.com"

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  # Associations
  has_many :created_prompts, class_name: 'Prompt', foreign_key: 'created_by_id', dependent: :nullify
  has_many :updated_prompts, class_name: 'Prompt', foreign_key: 'updated_by_id', dependent: :nullify
  has_many :prompt_versions, foreign_key: 'created_by_id', dependent: :nullify
  has_many :token_families, dependent: :destroy
end
