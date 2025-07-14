# frozen_string_literal: true

class AiLog < ApplicationRecord
  # Validations
  validates :model, presence: true
  validates :query, presence: true
  validates :settings, presence: true
  validates :input_tokens, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :output_tokens, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_model, ->(model_name) { where(model: model_name) if model_name.present? }
  scope :with_chat, -> { where.not(chat_id: nil) }
  scope :without_chat, -> { where(chat_id: nil) }

  # Instance methods
  def model_display_name
    model&.humanize || 'Unknown Model'
  end

  def query_preview(limit = 100)
    return '' if query.blank?
    
    if query.length > limit
      "#{query[0...limit]}..."
    else
      query
    end
  end

  def response_preview(limit = 100)
    return '' if response.blank?
    
    if response.length > limit
      "#{response[0...limit]}..."
    else
      response
    end
  end

  def total_cost
    cost = read_attribute(:total_cost)
    return 0 unless cost&.nonzero?

    return cost.round(2) if cost >= 1

    decimal_part = cost.to_s.split('.').last || '' 
    leading_zeros = decimal_part[/\A0*/]&.size || 0
    decimal_places = [[leading_zeros + 1, 2].max, 7].min

    cost.round(decimal_places) 
  end

  def settings_summary
    return {} if settings.blank?
    
    # Extract key settings for display
    summary = {}
    summary[:temperature] = settings['temperature'] if settings['temperature']
    summary[:max_tokens] = settings['max_tokens'] if settings['max_tokens']
    summary[:top_p] = settings['top_p'] if settings['top_p']
    summary
  end

  def has_chat_session?
    chat_id.present?
  end

  def response_length
    response&.length || 0
  end

  def query_length
    query&.length || 0
  end

  def total_tokens
    (input_tokens || 0) + (output_tokens || 0)
  end

  def has_token_data?
    input_tokens.present? || output_tokens.present?
  end

  def token_summary
    return "No token data" unless has_token_data?

    parts = []
    parts << "#{input_tokens} in" if input_tokens.present?
    parts << "#{output_tokens} out" if output_tokens.present?
    parts << "#{total_tokens} total" if total_tokens > 0

    parts.join(", ")
  end

  def completed?
    response.present?
  end

  def pending?
    response.blank?
  end
end
