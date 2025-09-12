# frozen_string_literal: true

ActiveAdmin.register AllowedModel do
  menu parent: "Ai Admin"

  permit_params :model, :active, :default

  config.batch_actions = false

  index do
    selectable_column
    id_column
    column :name
    column :model
    column :provider
    column :context_size do |allowed_model|
      allowed_model.context_size_display
    end
    column :active do |allowed_model|
      if allowed_model.active?
        span 'Active', class: 'status_tag ok'
      else
        span 'Inactive', class: 'status_tag error'
      end
    end
    column :default do |allowed_model|
      if allowed_model.default?
        span 'Default', class: 'status_tag warning'
      else
        span '-', class: 'status_tag'
      end
    end
    column :created_at
    column :updated_at
    actions
  end

  filter :name
  filter :model
  filter :provider, as: :select, collection: -> { AllowedModel.distinct.pluck(:provider).compact.sort }
  filter :active, as: :select, collection: [['Active', true], ['Inactive', false]]
  filter :default, as: :select, collection: [['Default', true], ['Not Default', false]]
  filter :created_at
  filter :updated_at

  show do
    attributes_table do
      row :id
      row :name
      row :model
      row :provider
      row :context_size do |allowed_model|
        "#{allowed_model.context_size_display} (#{allowed_model.context_size})" if allowed_model.context_size
      end
      row :active do |allowed_model|
        if allowed_model.active?
          span 'Active', class: 'status_tag ok'
        else
          span 'Inactive', class: 'status_tag error'
        end
      end
      row :default do |allowed_model|
        if allowed_model.default?
          span 'Default', class: 'status_tag warning'
        else
          span 'Not Default', class: 'status_tag'
        end
      end
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "Model Details" do
      if f.object.new_record?
        # Add the searchable dropdown with inline assets
        div style: "margin-bottom: 20px;" do
          raw <<~HTML
            <link href="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/css/select2.min.css" rel="stylesheet" />
            <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
            <script src="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/js/select2.min.js"></script>
            <style>
              .select2-container { width: 100% !important; }
              .select2-container--default .select2-selection--single {
                height: 38px; border: 1px solid #555; border-radius: 4px;
                background-color: #2a2a2a; color: #e0e0e0;
              }
              .select2-container--default .select2-selection--single .select2-selection__rendered {
                line-height: 36px; padding-left: 12px; color: #e0e0e0;
              }
              .select2-container--default .select2-selection--single .select2-selection__arrow {
                height: 36px;
              }
              .select2-container--default .select2-selection--single .select2-selection__arrow b {
                border-color: #e0e0e0 transparent transparent transparent;
              }
              .select2-dropdown {
                border: 1px solid #555; border-radius: 4px;
                background-color: #2a2a2a; color: #e0e0e0;
              }
              .select2-search--dropdown {
                background-color: #2a2a2a; padding: 8px;
              }
              .select2-search--dropdown .select2-search__field {
                background-color: #1a1a1a; color: #e0e0e0; border: 1px solid #555;
                padding: 8px 12px; border-radius: 4px;
              }
              .select2-search--dropdown .select2-search__field:focus {
                border-color: #5897fb; outline: none;
              }
              .select2-results__option {
                padding: 8px 12px; background-color: #2a2a2a; color: #e0e0e0;
              }
              .select2-results__option--highlighted {
                background-color: #5897fb !important; color: white !important;
              }
              .select2-results__option--selected {
                background-color: #404040; color: #5897fb;
              }
              .select2-results__option:hover {
                background-color: #404040; color: #e0e0e0;
              }
              .select2-container--default .select2-selection--single .select2-selection__placeholder {
                color: #999;
              }
              .select2-container--default.select2-container--focus .select2-selection--single {
                border-color: #5897fb;
              }
              .select2-results {
                background-color: #2a2a2a;
              }
              /* Dark theme for model preview box */
              #model-preview {
                background-color: #2a2a2a !important;
                color: #e0e0e0 !important;
                border-left: 4px solid #5897fb !important;
                border-radius: 4px;
              }
            </style>
          HTML
        end

        f.input :model, as: :select,
                collection: AllowedModel.available_models_for_dropdown.map { |m|
                  ["#{m[:name]} (#{m[:provider]}) - #{m[:context_size] ? "#{m[:context_size]} tokens" : "Unknown context"}", m[:id]]
                },
                prompt: "Select a model...",
                input_html: {
                  id: 'model_select',
                  class: 'searchable-select',
                  data: {
                    models: AllowedModel.available_models_for_dropdown.to_json
                  }
                }

        # Add JavaScript immediately after the select
        script type: "text/javascript" do
          raw <<~JAVASCRIPT
            (function() {
              function initSelect2() {
                if (typeof jQuery === 'undefined') {
                  setTimeout(initSelect2, 100);
                  return;
                }

                jQuery(document).ready(function($) {
                  var modelSelect = $('#model_select');
                  if (modelSelect.length === 0) return;

                  // Destroy existing select2 if it exists
                  if (modelSelect.hasClass('select2-hidden-accessible')) {
                    modelSelect.select2('destroy');
                  }

                  // Initialize Select2
                  modelSelect.select2({
                    placeholder: 'Search and select a model...',
                    allowClear: true,
                    width: '100%',
                    dropdownAutoWidth: true,
                    matcher: function(params, data) {
                      if ($.trim(params.term) === '') return data;
                      if (typeof data.text === 'undefined') return null;

                      var searchTerm = params.term.toLowerCase();
                      var displayText = data.text.toLowerCase();
                      var modelId = data.id ? data.id.toLowerCase() : '';

                      if (displayText.indexOf(searchTerm) > -1 || modelId.indexOf(searchTerm) > -1) {
                        return data;
                      }
                      return null;
                    }
                  });

                  // Auto-focus search field when dropdown opens
                  modelSelect.on('select2:open', function() {
                    setTimeout(function() {
                      $('.select2-search--dropdown .select2-search__field').focus();
                    }, 100);
                  });

                  // Handle selection changes
                  var modelsData = JSON.parse(modelSelect.attr('data-models') || '[]');
                  modelSelect.on('change', function() {
                    var selectedModelId = this.value;
                    var selectedModel = modelsData.find(function(m) { return m.id === selectedModelId; });

                    // Remove existing preview
                    $('#model-preview').remove();

                    if (selectedModel && selectedModelId) {
                      var preview = $('<div id="model-preview" style="margin-top: 10px; padding: 10px; background-color: #2a2a2a; color: #e0e0e0; border-radius: 4px; border-left: 4px solid #5897fb;">' +
                        '<strong style="color: #e0e0e0;">Selected Model Details:</strong><br>' +
                        '<strong style="color: #b0b0b0;">Name:</strong> <span style="color: #e0e0e0;">' + selectedModel.name + '</span><br>' +
                        '<strong style="color: #b0b0b0;">Provider:</strong> <span style="color: #e0e0e0;">' + selectedModel.provider + '</span><br>' +
                        '<strong style="color: #b0b0b0;">Context Size:</strong> <span style="color: #e0e0e0;">' + (selectedModel.context_size ? selectedModel.context_size.toLocaleString() + ' tokens' : 'Unknown') + '</span><br>' +
                        '<strong style="color: #b0b0b0;">Model ID:</strong> <span style="color: #5897fb;">' + selectedModel.id + '</span>' +
                        '</div>');

                      modelSelect.parent().append(preview);
                    }
                  });
                });
              }

              initSelect2();
            })();
          JAVASCRIPT
        end

      else
        f.input :model, input_html: { readonly: true, disabled: true }
        para "Model cannot be changed after creation. Create a new allowed model if needed."
      end

      f.input :active, as: :boolean
      f.input :default, as: :boolean,
              hint: "Only one model can be set as default. Setting this will remove default from other models."
    end

    f.actions
  end

  controller do
    def create
      # Extract model data from RubyLLM
      model_id = permitted_params[:allowed_model][:model]
      available_models = AllowedModel.available_models_for_dropdown
      selected_model = available_models.find { |m| m[:id] == model_id }
      
      if selected_model.nil?
        redirect_to new_admin_allowed_model_path, alert: 'Invalid model selected.'
        return
      end

      @allowed_model = AllowedModel.new(permitted_params[:allowed_model])
      @allowed_model.name = selected_model[:name]
      @allowed_model.provider = selected_model[:provider]
      @allowed_model.context_size = selected_model[:context_size]

      if @allowed_model.save
        redirect_to admin_allowed_model_path(@allowed_model), notice: 'Allowed model was successfully created.'
      else
        render :new
      end
    end

    def update
      @allowed_model = resource
      
      # Don't allow changing the model field
      params[:allowed_model].delete(:model) if params[:allowed_model]
      
      if @allowed_model.update(permitted_params[:allowed_model])
        redirect_to admin_allowed_model_path(@allowed_model), notice: 'Allowed model was successfully updated.'
      else
        render :edit
      end
    end
  end

  # Add action to make a model default
  member_action :make_default, method: :patch do
    resource.make_default!
    redirect_to admin_allowed_models_path, notice: "#{resource.name} is now the default model."
  end

  action_item :make_default, only: :show, if: proc { !resource.default? } do
    link_to "Make Default", make_default_admin_allowed_model_path(resource), 
            method: :patch, 
            data: { confirm: "Are you sure you want to make this the default model?" },
            class: "button"
  end
end
