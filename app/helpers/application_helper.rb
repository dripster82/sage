# frozen_string_literal: true

module ApplicationHelper
  # Generate model dropdown options for ActiveAdmin form selects
  # Returns an array of [display_text, value] pairs
  # @param models [ActiveRecord::Relation] Collection of AllowedModel records (default: AllowedModel.active.order(:name))
  # @return [Array] Array of [display_text, model_id] pairs
  def model_dropdown_options(models = AllowedModel.active.order(:name))
    models.map do |m|
      context_str = m.context_size ? "#{m.context_size} tokens" : "Unknown context"
      pricing_str = m.pricing_display
      ["#{m.display_name} - #{context_str} - #{pricing_str}", m.id]
    end
  end

  # Generate model dropdown options for JavaScript dropdowns
  # Returns an array of hashes with id, name, provider, and context for JSON serialization
  # @param models [ActiveRecord::Relation] Collection of AllowedModel records (default: AllowedModel.active.order(:name))
  # @return [Array] Array of hashes with id, name, provider, and context keys
  def model_dropdown_options_for_js(models = AllowedModel.active.order(:name))
    models.map do |m|
      pricing_str = m.pricing_display
      {
        id: m.model,
        name: "#{m.name} (#{m.provider}) - #{m.context_size} tokens - #{pricing_str}",
        provider: m.provider,
        context: m.context_size
      }
    end
  end
end
