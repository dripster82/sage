# frozen_string_literal: true

ActiveAdmin.register Prompt do
  menu parent: "Ai Admin"

  permit_params :name, :content, :description, :category, :status, :metadata

  config.batch_actions = false

  member_action :revert, method: :post do
    version_number = params[:version_number].to_i
    change_summary = "Reverted to version #{version_number} via admin interface"

    begin
      resource.revert_to_version!(
        version_number,
        reverted_by: current_admin_user,
        change_summary: change_summary
      )
      redirect_to admin_prompt_path(resource),
                  notice: "Successfully reverted to version #{version_number}"
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_prompt_path(resource),
                  alert: "Version #{version_number} not found"
    rescue => e
      redirect_to admin_prompt_path(resource),
                  alert: "Error reverting: #{e.message}"
    end
  end

  member_action :delete_version, method: :delete do
    version_number = params[:version_number].to_i

    begin
      unless resource.can_delete_version?(version_number)
        redirect_to admin_prompt_path(resource),
                    alert: "Cannot delete this version (it may be current or the only version)"
        return
      end

      resource.delete_version!(version_number)
      redirect_to admin_prompt_path(resource),
                  notice: "Successfully deleted version #{version_number}"
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_prompt_path(resource),
                  alert: "Version #{version_number} not found"
    rescue => e
      redirect_to admin_prompt_path(resource),
                  alert: "Error deleting version: #{e.message}"
    end
  end

  controller do
    def create
      @prompt = Prompt.new(permitted_params[:prompt])
      @prompt.created_by = current_admin_user
      @prompt.updated_by = current_admin_user

      if @prompt.save
        redirect_to admin_prompt_path(@prompt), notice: 'Prompt was successfully created.'
      else
        render :new
      end
    end

    def update
      @prompt = resource
      @prompt.updated_by = current_admin_user

      if @prompt.update(permitted_params[:prompt])
        redirect_to admin_prompt_path(@prompt), notice: 'Prompt was successfully updated.'
      else
        render :edit
      end
    end


  end

  index do
    selectable_column
    id_column
    column :name
    column :category
    column :status do |prompt|
      status_tag prompt.status
    end
    column :current_version 
    column :tags do |prompt|
      if prompt.tags_list.any?
        prompt.tags_list.join(", ").html_safe
      else
        span "No tags", class: "text-gray-500"
      end
    end
    column :created_by, &:created_by
    column :updated_by, &:updated_by
    column :created_at
    column :updated_at
    actions do |prompt|
      link_to "Versions", admin_prompt_path(prompt, anchor: "versions"), class: "member_link"
    end
  end

  filter :name
  filter :category
  filter :status, as: :select, collection: %w[active inactive draft]
  filter :created_by
  filter :updated_by
  filter :created_at
  filter :updated_at

  show do
    attributes_table do
      row :id
      row :name
      row :description
      row :category
      row :tags do |prompt|
        if prompt.tags_list.any?
          prompt.tags_list.join(", ").html_safe
        else
          span "No tags", class: "text-gray-500"
        end
      end
      row :status do |prompt|
        status_tag prompt.status
      end
      row :current_version
      row :content do |prompt|
        simple_format prompt.content
      end
      row :metadata do |prompt|
        pre JSON.pretty_generate(prompt.metadata) if prompt.metadata.present?
      end
      row :created_by
      row :updated_by
      row :created_at
      row :updated_at
    end

    panel "Version History", id: "versions" do
      # Hidden version content for JavaScript access
      prompt.version_history.each do |version|
        div id: "version-content-#{version.id}", style: "display: none;" do
          h4 "Version #{version.version_number} Content", class: "text-lg font-semibold mb-4 text-gray-900 dark:text-gray-100"
          div class: "version-details space-y-4" do
            div class: "flex flex-col sm:flex-row sm:items-center" do
              strong "Name: ", class: "text-gray-700 dark:text-gray-300 sm:w-24 sm:flex-shrink-0"
              span version.name, class: "text-gray-900 dark:text-gray-100"
            end
            div class: "flex flex-col sm:flex-row sm:items-center" do
              strong "Description: ", class: "text-gray-700 dark:text-gray-300 sm:w-24 sm:flex-shrink-0"
              span (version.description || "No description"), class: "text-gray-900 dark:text-gray-100"
            end
            div class: "flex flex-col sm:flex-row sm:items-center" do
              strong "Category: ", class: "text-gray-700 dark:text-gray-300 sm:w-24 sm:flex-shrink-0"
              span (version.category || "No category"), class: "text-gray-900 dark:text-gray-100"
            end
            div class: "mt-4" do
              strong "Content:", class: "text-gray-700 dark:text-gray-300 block mb-2"
              pre class: "bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-gray-100 p-4 rounded-md border border-gray-200 dark:border-gray-600 whitespace-pre-wrap text-sm overflow-x-auto" do
                version.content
              end
            end
            if version.metadata.present?
              div class: "mt-4" do
                strong "Metadata:", class: "text-gray-700 dark:text-gray-300 block mb-2"
                pre class: "bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-gray-100 p-4 rounded-md border border-gray-200 dark:border-gray-600 text-sm overflow-x-auto" do
                  JSON.pretty_generate(version.metadata)
                end
              end
            end
          end
        end
      end

      table_for prompt.version_history do
        column :version_number do |version|
          if version.is_current?
            strong "#{version.version_number} (Current)"
          else
            version.version_number
          end
        end
        column :change_summary
        column :created_by, &:created_by_name
        column :created_at
        column "Actions" do |version|
          actions = []

          # View button (only for non-current versions)
          unless version.is_current?
            actions << link_to("View", "#",
                              class: "btn btn-sm btn-info view-version-btn",
                              data: {
                                version_id: version.id,
                                version_number: version.version_number
                              })

            # Revert button (only for non-current versions)
            actions << link_to("Revert",
                              revert_admin_prompt_path(prompt, version_number: version.version_number),
                              method: :post,
                              class: "btn btn-sm btn-warning",
                              data: {
                                confirm: "Are you sure you want to revert to version #{version.version_number}? This will create a new version with the content from version #{version.version_number}.",
                                disable_with: "Reverting...",
                                remote: false
                              })

            # Delete button (only for non-current versions and if more than 1 version exists)
            if prompt.prompt_versions.count > 1
              actions << link_to("Delete",
                                delete_version_admin_prompt_path(prompt, version_number: version.version_number),
                                method: :delete,
                                class: "btn btn-sm btn-danger",
                                data: {
                                  confirm: "Are you sure you want to permanently delete version #{version.version_number}? This action cannot be undone.",
                                  disable_with: "Deleting...",
                                  remote: false
                                })
            end
          end

          raw actions.join(" ")
        end
      end
    end

    # Modal for viewing version content
    div id: "version-modal", class: "modal-overlay", style: "display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; background-color: rgba(0,0,0,0.5);" do
      div class: "modal-content bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100",
          style: "margin: 5% auto; padding: 0; border-radius: 8px; width: 80%; max-width: 800px; max-height: 80%; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);" do

        # Modal header
        div class: "modal-header bg-gray-50 dark:bg-gray-700 border-b border-gray-200 dark:border-gray-600",
            style: "padding: 16px 20px; display: flex; justify-content: space-between; align-items: center;" do
          h3 "Version Content", id: "modal-title", class: "text-lg font-semibold text-gray-900 dark:text-gray-100"
          button "×", id: "close-modal",
                  class: "text-gray-400 hover:text-gray-600 dark:text-gray-300 dark:hover:text-gray-100",
                  style: "background: none; border: none; font-size: 24px; cursor: pointer; padding: 0; line-height: 1;"
        end

        # Modal body
        div id: "modal-content", class: "modal-body", style: "padding: 20px; overflow-y: auto; max-height: calc(80vh - 80px);" do
          text_node ""
        end
      end
    end

    # JavaScript for modal functionality
    script do
      raw <<~JAVASCRIPT
        document.addEventListener('DOMContentLoaded', function() {
          const modal = document.getElementById('version-modal');
          const modalTitle = document.getElementById('modal-title');
          const modalContent = document.getElementById('modal-content');
          const closeModal = document.getElementById('close-modal');

          // Handle view button clicks
          document.querySelectorAll('.view-version-btn').forEach(function(btn) {
            btn.addEventListener('click', function(e) {
              e.preventDefault();
              const versionId = this.dataset.versionId;
              const versionNumber = this.dataset.versionNumber;
              const contentDiv = document.getElementById('version-content-' + versionId);

              if (contentDiv) {
                modalTitle.textContent = 'Version ' + versionNumber + ' Content';
                modalContent.innerHTML = contentDiv.innerHTML;
                modal.style.display = 'block';
              }
            });
          });

          // Close modal handlers
          closeModal.addEventListener('click', function() {
            modal.style.display = 'none';
          });

          modal.addEventListener('click', function(e) {
            if (e.target === modal) {
              modal.style.display = 'none';
            }
          });

          // Close on escape key
          document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape' && modal.style.display === 'block') {
              modal.style.display = 'none';
            }
          });
        });
      JAVASCRIPT
    end
  end

  form do |f|
    f.inputs "Prompt Details" do
      f.input :name, as: :string
      f.input :description, as: :text, input_html: { rows: 2 }
      f.input :category
      f.input :status, as: :select, collection: %w[active inactive draft]
      f.input :content, as: :text, input_html: { rows: 25 }
    end
    f.actions
  end
end
