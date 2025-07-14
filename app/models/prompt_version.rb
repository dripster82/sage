# frozen_string_literal: true

class PromptVersion < ApplicationRecord
  # Associations
  belongs_to :prompt
  belongs_to :created_by, class_name: 'AdminUser'

  # Validations
  validates :version_number, presence: true, 
            uniqueness: { scope: :prompt_id },
            numericality: { greater_than: 0 }
  validates :content, presence: true
  validates :name, presence: true

  # Scopes
  scope :current, -> { where(is_current: true) }
  scope :historical, -> { where(is_current: false) }
  scope :ordered, -> { order(:version_number) }
  scope :recent_first, -> { order(version_number: :desc) }

  # Instance methods
  def previous_version
    prompt.prompt_versions
          .where('version_number < ?', version_number)
          .order(version_number: :desc)
          .first
  end

  def next_version
    prompt.prompt_versions
          .where('version_number > ?', version_number)
          .order(:version_number)
          .first
  end

  def is_latest?
    version_number == prompt.current_version
  end

  def content_diff_from_previous
    prev = previous_version
    return nil unless prev
    
    {
      previous_content: prev.content,
      current_content: content,
      changes: calculate_changes(prev)
    }
  end

  def restore!
    prompt.revert_to_version!(
      version_number, 
      reverted_by: prompt.updated_by,
      change_summary: "Restored from version #{version_number}"
    )
  end

  def summary
    change_summary.presence || "Version #{version_number}"
  end

  def created_by_name
    created_by&.email || 'Unknown'
  end

  def age
    Time.current - created_at
  end

  def formatted_age
    age_in_seconds = age.to_i
    
    case age_in_seconds
    when 0..59
      "#{age_in_seconds} seconds ago"
    when 60..3599
      "#{age_in_seconds / 60} minutes ago"
    when 3600..86399
      "#{age_in_seconds / 3600} hours ago"
    else
      "#{age_in_seconds / 86400} days ago"
    end
  end

  private

  def calculate_changes(previous_version)
    changes = {}
    
    changes[:content] = content != previous_version.content
    changes[:name] = name != previous_version.name
    changes[:description] = description != previous_version.description
    changes[:category] = category != previous_version.category
    changes[:metadata] = metadata != previous_version.metadata
    
    changes
  end
end
