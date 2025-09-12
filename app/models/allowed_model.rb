# frozen_string_literal: true

class AllowedModel < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :model, presence: true, uniqueness: true
  validates :provider, presence: true
  validates :active, inclusion: { in: [true, false] }
  validates :default, inclusion: { in: [true, false] }
  validates :context_size, numericality: { greater_than: 0 }, allow_nil: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :default_model, -> { where(default: true) }
  scope :by_provider, ->(provider) { where(provider: provider) if provider.present? }

  # Callbacks
  before_save :ensure_single_default

  # Class methods
  def self.available_models_for_dropdown
    RubyLLM.models.map do |model|
      {
        name: model.name,
        id: model.id,
        provider: model.provider,
        context_size: model.context_window
      }
    end
  end

  def self.get_default_model
    default_model.active.first
  end

  def self.get_fallback_model
    # Try to get the default allowed model first
    fallback = get_default_model
    return fallback if fallback

    # If no default, try to find the RubyLLM default in our allowed models
    ruby_llm_default = RubyLLM.config.default_model
    fallback = active.find_by(model: ruby_llm_default)
    return fallback if fallback

    # Last resort: return the first active model
    active.first
  end

  # Instance methods
  def display_name
    "#{name} (#{provider})"
  end

  def context_size_display
    return 'Unknown' if context_size.nil?
    
    if context_size >= 1_000_000
      "#{(context_size / 1_000_000.0).round(1)}M"
    elsif context_size >= 1_000
      "#{(context_size / 1_000.0).round(1)}K"
    else
      context_size.to_s
    end
  end

  def is_default?
    default
  end

  def make_default!
    transaction do
      # Remove default from all other models
      self.class.where.not(id: id).update_all(default: false)
      # Set this model as default
      update!(default: true)
    end
  end

  private

  def ensure_single_default
    return unless default_changed? && default?

    # If this model is being set as default, remove default from all others
    AllowedModel.where.not(id: id).update_all(default: false)
  end
end
