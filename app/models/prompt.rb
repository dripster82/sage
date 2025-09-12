# frozen_string_literal: true

class Prompt < ApplicationRecord
  # Associations
  belongs_to :created_by, class_name: 'AdminUser'
  belongs_to :updated_by, class_name: 'AdminUser'
  belongs_to :allowed_model, optional: true
  has_many :prompt_versions, dependent: :destroy
  has_one :current_version_record, -> { where(is_current: true) },
          class_name: 'PromptVersion'

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :content, presence: true
  validates :status, presence: true, inclusion: { in: %w[active inactive draft] }
  validates :current_version, presence: true, numericality: { greater_than: 0 }

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :inactive, -> { where(status: 'inactive') }
  scope :draft, -> { where(status: 'draft') }
  scope :by_category, ->(category) { where(category: category) if category.present? }

  # Callbacks
  after_create :create_initial_version
  before_update :create_new_version_if_content_changed
  before_save :extract_tags_from_content

  # Instance methods
  def create_version!(change_summary: nil, created_by: nil)
    new_version_number = current_version + 1
    
    # Mark current version as not current
    current_version_record&.update!(is_current: false)
    
    # Create new version
    version = prompt_versions.create!(
      version_number: new_version_number,
      content: content,
      name: name,
      description: description,
      category: category,
      metadata: metadata || {},
      change_summary: change_summary,
      is_current: true,
      created_by: created_by || updated_by
    )
    
    # Update current version number
    update_column(:current_version, new_version_number)
    
    version
  end

  def revert_to_version!(version_number, reverted_by:, change_summary: nil)
    target_version = prompt_versions.find_by!(version_number: version_number)
    
    # Update prompt with version data
    self.content = target_version.content
    self.name = target_version.name
    self.description = target_version.description
    self.category = target_version.category
    self.metadata = target_version.metadata
    self.updated_by = reverted_by
    
    # Save and create new version
    save!
    
    create_version!(
      change_summary: change_summary || "Reverted to version #{version_number}",
      created_by: reverted_by
    )
  end

  def version_history
    prompt_versions.order(:version_number)
  end

  def latest_versions(limit = 10)
    prompt_versions.order(version_number: :desc).limit(limit)
  end

  def version_at(version_number)
    prompt_versions.find_by(version_number: version_number)
  end

  def content_changed_since_last_version?
    return true if prompt_versions.empty?
    
    current_version_record&.content != content ||
    current_version_record&.name != name ||
    current_version_record&.description != description ||
    current_version_record&.category != category
  end

  def tags_list
    @tags_list ||= JSON.parse(tags || '[]')
  end

  def tags_hash
    @tags_hash ||= tags_list.map(&:to_sym).index_with { nil }
  end

  def effective_model
    return allowed_model.model if allowed_model&.active?

    # Fallback to default allowed model
    default_model = AllowedModel.get_default_model
    return default_model.model if default_model

    # Final fallback to RubyLLM default
    RubyLLM.config.default_model
  end

  def model_display_name
    return allowed_model.display_name if allowed_model

    "Default (#{RubyLLM.config.default_model})"
  end

  private

  def extract_tags_from_content
    return unless content.present?

    # Extract tags in the format {{tag_name}} from content
    extracted_tags = content.scan(/%\{([^}]+)\}/).flatten.map(&:strip).uniq.sort
    self.tags = extracted_tags.to_json
  end

  def create_initial_version
    prompt_versions.create!(
      version_number: 1,
      content: content,
      name: name,
      description: description,
      category: category,
      metadata: metadata || {},
      change_summary: 'Initial version',
      is_current: true,
      created_by: created_by
    )
  end

  def create_new_version_if_content_changed
    if content_changed_since_last_version? && persisted?
      # This will be called after_update via callback
      @should_create_version = true
    end
  end

  # This needs to be after_update to ensure the changes are saved first
  after_update :create_version_after_update

  def create_version_after_update
    if @should_create_version
      create_version!(
        change_summary: 'Content updated',
        created_by: updated_by
      )
      @should_create_version = false
    end
  end
end
