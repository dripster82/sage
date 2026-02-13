# frozen_string_literal: true

ActiveAdmin.register AiLog do
  menu parent: "Ai Admin"

  permit_params :model, :settings, :query, :response, :chat_id, :input_tokens, :session_uuid, :output_tokens, :prompt_key, :duration_ms

  config.batch_actions = false

  index do
    selectable_column
    id_column
    column :model do |ai_log|
      ai_log.model_display_name
    end
    column :prompt_key do |ai_log|
      if ai_log.prompt_key.present?
        truncate(ai_log.prompt_key, length: 50)
      else
        span "Not matched", class: "text-gray-500"
      end
    end
    column :query do |ai_log|
      truncate(ai_log.query_preview(80), length: 80)
    end
    column :response do |ai_log|
      if ai_log.completed?
        truncate(ai_log.response_preview(80), length: 80)
      else
        status_tag "Pending", class: "warning"
      end
    end
    column :chat_id do |ai_log|
      if ai_log.has_chat_session?
        ai_log.chat_id
      else
        span "No chat", class: "text-gray-500"
      end
    end
    column "Session", :session_uuid do |ai_log|
      if ai_log.session_uuid.present?
        ai_log.session_uuid
      else
        span "No session id", class: "text-gray-500"
      end
    end
    column :tokens do |ai_log|
      if ai_log.has_token_data?
        ai_log.token_summary
      else
        span "No token data", class: "text-gray-500"
      end
    end
    column "Cost($)", :cost do |ai_log|
      if ai_log.total_cost > 0
        ai_log.total_cost
      else
        span "No cost data", class: "text-gray-500"
      end
    end
    column :status do |ai_log|
      if ai_log.completed?
        status_tag "Completed", class: "success"
      else
        status_tag "Pending", class: "warning"
      end
    end
    column :created_at do |ai_log|
      div do
        div ai_log.created_at.strftime("%B %d, %Y %H:%M")
        div "(#{ai_log.duration_display})", style: "color: #999; font-size: 0.9em; margin-top: 2px;"
      end
    end
    actions do |ai_log|
      item "Model Test", "#", class: "member_link", onclick: "openModelTestModal(#{ai_log.id}, #{ai_log.query.to_json}, #{ai_log.model.to_json}, #{ai_log.prompt_key.to_json}); return false;"
    end
  end

  filter :model
  filter :chat_id
  filter :session_uuid
  filter :input_tokens
  filter :output_tokens
  filter :created_at
  filter :updated_at

  show do
    attributes_table do
      row :id
      row :model do |ai_log|
        ai_log.model_display_name
      end
      row :chat_id do |ai_log|
        if ai_log.has_chat_session?
          ai_log.chat_id
        else
          span "No chat session", class: "text-gray-500"
        end
      end
      row :session_uuid do |ai_log|
        if ai_log.session_uuid.present?
          ai_log.session_uuid
        else
          span "No session id", class: "text-gray-500"
        end
      end
      row :input_tokens do |ai_log|
        ai_log.input_tokens || span("Not available", class: "text-gray-500")
      end
      row :output_tokens do |ai_log|
        ai_log.output_tokens || span("Not available", class: "text-gray-500")
      end
      row :total_tokens do |ai_log|
        if ai_log.has_token_data?
          ai_log.total_tokens
        else
          span "Not available", class: "text-gray-500"
        end
      end
      row :status do |ai_log|
        if ai_log.completed?
          status_tag "Completed", class: "success"
        else
          status_tag "Pending", class: "warning"
        end
      end
      row :settings do |ai_log|
        if ai_log.settings.present?
          pre JSON.pretty_generate(ai_log.settings), class: "bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-gray-100 p-4 rounded-md border border-gray-200 dark:border-gray-600 text-sm overflow-x-auto"
        else
          span "No settings", class: "text-gray-500"
        end
      end
      row :query do |ai_log|
        div class: "bg-blue-50 dark:bg-blue-900/20 p-4 rounded-md border border-blue-200 dark:border-blue-800" do
          h4 "Query", class: "text-blue-800 dark:text-blue-200 font-semibold mb-2"
          pre ai_log.query, class: "text-blue-900 dark:text-blue-100 whitespace-pre-wrap text-sm"
        end
      end
      row :response do |ai_log|
        if ai_log.completed?
          div class: "bg-green-50 dark:bg-green-900/20 p-4 rounded-md border border-green-200 dark:border-green-800" do
            h4 "Response", class: "text-green-800 dark:text-green-200 font-semibold mb-2"
            pre ai_log.response, class: "text-green-900 dark:text-green-100 whitespace-pre-wrap text-sm"
          end
        else
          div class: "bg-yellow-50 dark:bg-yellow-900/20 p-4 rounded-md border border-yellow-200 dark:border-yellow-800" do
            h4 "Response", class: "text-yellow-800 dark:text-yellow-200 font-semibold mb-2"
            span "Response pending...", class: "text-yellow-900 dark:text-yellow-100 italic"
          end
        end
      end
      row :created_at
      row :updated_at
    end

    panel "Settings Summary" do
      if resource.settings_summary.any?
        table_for [resource.settings_summary] do
          resource.settings_summary.each do |key, value|
            column key.to_s.humanize, key
          end
        end
      else
        para "No key settings to display"
      end
    end
  end

  form do |f|
    f.inputs "AI Log Details" do
      f.input :model, as: :string, hint: "The AI model used (e.g., gpt-4, claude-3, etc.)"
      f.input :chat_id, as: :number, hint: "Leave blank for standalone queries"
      f.input :session_uuid, as: :string, hint: "The session UUID for grouping related queries"
      f.input :query, as: :text, input_html: { rows: 8 }, hint: "The input query sent to the AI"
      f.input :response, as: :text, input_html: { rows: 12 }, hint: "The response received from the AI (optional, can be filled later)"
      f.input :input_tokens, as: :number, hint: "Number of input tokens used"
      f.input :output_tokens, as: :number, hint: "Number of output tokens generated"
      f.input :settings, as: :text, input_html: { rows: 6 }, hint: "JSON settings used for the AI request (e.g., temperature, max_tokens)"
    end
    f.actions
  end

  # Handle model test requests
  controller do
    def model_test
      begin
        # Set session for admin testing
        Current.ailog_session = "ADMIN_TEST"

        model = params[:model]
        query = params[:query]
        prompt_key = params[:prompt_key]

        # Record start time
        start_time = Time.current

        # Create a query service to test the model
        service = Llm::QueryService.new(model: model, temperature: 0.7)
        response = service.ask(query, prompt_key: prompt_key)

        # Calculate processing time
        processing_time = ((Time.current - start_time) * 1000).round(2)

        # Convert markdown to HTML
        markdown_html = render_markdown(response.content)

        # Return JSON response
        render json: {
          response: response.content,
          markdown_html: markdown_html,
          model: model,
          processing_time: processing_time,
          input_tokens: response.input_tokens,
          output_tokens: response.output_tokens
        }

      rescue => e
        render json: { error: e.message }, status: 422
      ensure
        # Clean up session
        Current.ailog_session = nil
      end
    end

    private

    def render_markdown(text)
      return '' if text.blank?

      html = begin
        # Prefer CommonMarker when available for predictable markdown rendering.
        require 'commonmarker'
        CommonMarker.render_html(text, :DEFAULT, %i[table strikethrough autolink])
      rescue LoadError
        begin
          # Fallback to GitHub Markup if CommonMarker isn't available.
          require 'github/markup'
          GitHub::Markup.render('README.md', text)
        rescue LoadError
          # Final fallback when no markdown gem is installed.
          ActionController::Base.helpers.simple_format(ERB::Util.html_escape(text))
        end
      end

      # Post-process to add target="_blank" to external links
      html.gsub(/<a href="(https?:\/\/[^"]+)"([^>]*)>/) do |match|
        url = $1
        attributes = $2
        unless attributes.include?('target=')
          attributes += ' target="_blank" rel="noopener noreferrer"'
        end
        "<a href=\"#{url}\"#{attributes}>"
      end
    rescue
      # If markdown parsing fails, return the original text wrapped in <pre>
      "<pre>#{ERB::Util.html_escape(text)}</pre>"
    end
  end

  # Model Test Modal and JavaScript
  sidebar "Model Test Modal", only: :index do
    text_node raw(<<~HTML)
      <style nonce="#{content_security_policy_nonce}">
        .model-test-modal {
          display: none;
          position: fixed;
          z-index: 10000;
          left: 0;
          top: 0;
          width: 100%;
          height: 100%;
          background-color: rgba(0, 0, 0, 0.5);
        }

        .model-test-modal.show {
          display: flex;
          align-items: center;
          justify-content: center;
        }

        .model-test-modal-content {
          background-color: white;
          padding: 30px;
          border-radius: 8px;
          box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
          width: 70%;
          max-height: 90vh;
          overflow-y: auto;
        }

        .dark .model-test-modal-content {
          background-color: #1f2937;
          color: #f9fafb;
        }

        .model-test-modal-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 20px;
          border-bottom: 1px solid #e5e7eb;
          padding-bottom: 15px;
        }

        .dark .model-test-modal-header {
          border-bottom-color: #4b5563;
        }

        .model-test-modal-title {
          font-size: 20px;
          font-weight: 600;
          color: #1f2937;
        }

        .dark .model-test-modal-title {
          color: #f9fafb;
        }

        .model-test-modal-close {
          background: none;
          border: none;
          font-size: 28px;
          cursor: pointer;
          color: #6b7280;
        }

        .model-test-modal-close:hover {
          color: #1f2937;
        }

        .dark .model-test-modal-close:hover {
          color: #f9fafb;
        }

        .model-test-form-group {
          margin-bottom: 20px;
        }

        .model-test-label {
          display: block;
          font-weight: 600;
          margin-bottom: 8px;
          color: #374151;
          font-size: 14px;
        }

        .dark .model-test-label {
          color: #d1d5db;
        }

        .model-test-input, .model-test-textarea, .model-test-select {
          width: 100%;
          padding: 8px 12px;
          border: 1px solid #d1d5db;
          border-radius: 6px;
          font-size: 14px;
          background-color: white;
          color: #374151;
          font-family: inherit;
        }

        .dark .model-test-input, .dark .model-test-textarea, .dark .model-test-select {
          background-color: #374151;
          border-color: #4b5563;
          color: #f9fafb;
        }

        .model-test-input:focus, .model-test-textarea:focus, .model-test-select:focus {
          outline: none;
          border-color: #3b82f6;
          box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
        }

        .model-test-textarea {
          min-height: 120px;
          resize: vertical;
        }

        .model-test-buttons {
          display: flex;
          gap: 10px;
          justify-content: flex-end;
          margin-top: 20px;
        }

        .model-test-btn {
          padding: 10px 20px;
          border: none;
          border-radius: 6px;
          font-size: 14px;
          font-weight: 600;
          cursor: pointer;
          transition: background-color 0.2s;
        }

        .model-test-btn-primary {
          background-color: #3b82f6;
          color: white;
        }

        .model-test-btn-primary:hover {
          background-color: #2563eb;
        }

        .model-test-btn-primary:disabled {
          background-color: #9ca3af;
          cursor: not-allowed;
        }

        .model-test-btn-secondary {
          background-color: #e5e7eb;
          color: #374151;
        }

        .dark .model-test-btn-secondary {
          background-color: #4b5563;
          color: #f9fafb;
        }

        .model-test-btn-secondary:hover {
          background-color: #d1d5db;
        }

        .dark .model-test-btn-secondary:hover {
          background-color: #6b7280;
        }

        .model-test-response {
          margin-top: 20px;
          padding: 16px;
          background-color: #f9fafb;
          border-radius: 6px;
          border: 1px solid #e5e7eb;
          display: none;
        }

        .dark .model-test-response {
          background-color: #374151;
          border-color: #4b5563;
        }

        .model-test-response.show {
          display: block;
        }

        .model-test-response-title {
          font-size: 16px;
          font-weight: 600;
          margin-bottom: 12px;
          color: #1f2937;
        }

        .dark .model-test-response-title {
          color: #f9fafb;
        }

        .model-test-response-content {
          color: #374151;
          line-height: 1.6;
          white-space: pre-wrap;
          word-wrap: break-word;
          margin-bottom: 16px;
        }

        .dark .model-test-response-content {
          color: #d1d5db;
        }

        .model-test-stats {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
          gap: 12px;
          margin-top: 16px;
          padding-top: 16px;
          border-top: 1px solid #e5e7eb;
        }

        .dark .model-test-stats {
          border-top-color: #4b5563;
        }

        .model-test-stat-item {
          background: #f9fafb;
          padding: 10px;
          border-radius: 6px;
          border-left: 3px solid #3b82f6;
        }

        .dark .model-test-stat-item {
          background: #374151;
          border-left-color: #60a5fa;
        }

        .model-test-stat-label {
          font-size: 11px;
          font-weight: 600;
          text-transform: uppercase;
          letter-spacing: 0.05em;
          color: #6b7280;
          margin-bottom: 4px;
        }

        .dark .model-test-stat-label {
          color: #9ca3af;
        }

        .model-test-stat-value {
          font-size: 13px;
          font-weight: 500;
          color: #1f2937;
        }

        .dark .model-test-stat-value {
          color: #f9fafb;
        }

        .model-test-error {
          color: #dc2626;
          padding: 12px;
          background-color: #fef2f2;
          border: 1px solid #fecaca;
          border-radius: 6px;
          margin-top: 10px;
          display: none;
        }

        .dark .model-test-error {
          background-color: #7f1d1d;
          border-color: #dc2626;
          color: #fca5a5;
        }

        .model-test-error.show {
          display: block;
        }

        .model-test-loading {
          display: none;
          color: #6b7280;
          font-size: 14px;
          margin-left: 10px;
        }

        .model-test-loading.show {
          display: inline;
        }

        /* Tab styles */
        .model-test-tabs {
          display: flex;
          border-bottom: 2px solid #e9ecef;
          margin-bottom: 15px;
          gap: 0;
        }

        .dark .model-test-tabs {
          border-bottom-color: #4b5563;
        }

        .model-test-tab {
          padding: 10px 20px;
          background: none;
          border: none;
          border-bottom: 2px solid transparent;
          cursor: pointer;
          font-size: 14px;
          font-weight: 500;
          color: #6b7280;
          transition: all 0.2s ease;
        }

        .model-test-tab:hover {
          color: #374151;
          background-color: #f9fafb;
        }

        .model-test-tab-active {
          color: #3b82f6 !important;
          border-bottom-color: #3b82f6 !important;
          background-color: transparent !important;
        }

        .dark .model-test-tab {
          color: #9ca3af;
        }

        .dark .model-test-tab:hover {
          color: #f3f4f6;
          background-color: #374151;
        }

        .dark .model-test-tab-active {
          color: #60a5fa !important;
          border-bottom-color: #60a5fa !important;
        }

        .model-test-tab-content {
          position: relative;
        }

        .model-test-tab-pane {
          display: none;
        }

        .model-test-tab-pane-active {
          display: block !important;
        }

        .model-test-raw-text {
          background-color: #f8f9fa;
          border: 1px solid #e9ecef;
          border-radius: 6px;
          padding: 15px;
          margin: 0;
          white-space: pre-wrap;
          word-wrap: break-word;
          font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
          font-size: 13px;
          line-height: 1.4;
          color: #374151;
          overflow-x: auto;
        }

        .dark .model-test-raw-text {
          background-color: #1f2937;
          border-color: #374151;
          color: #f3f4f6;
        }
      </style>

      <div id="modelTestModal" class="model-test-modal">
        <div class="model-test-modal-content">
          <div class="model-test-modal-header">
            <h2 class="model-test-modal-title">Model Test</h2>
            <button class="model-test-modal-close" onclick="closeModelTestModal()">&times;</button>
          </div>

          <form id="modelTestForm">
            <div class="model-test-form-group">
              <label class="model-test-label">Model:</label>
              <select id="modelTestModelSelect" class="model-test-select" required>
                <option value="">Select a model...</option>
              </select>
            </div>

            <div class="model-test-form-group">
              <label class="model-test-label">Query:</label>
              <textarea id="modelTestQuery" class="model-test-textarea" required></textarea>
            </div>

            <div class="model-test-buttons">
              <button type="button" class="model-test-btn model-test-btn-secondary" onclick="closeModelTestModal()">Cancel</button>
              <button type="button" class="model-test-btn model-test-btn-primary" id="modelTestSubmitBtn" onclick="submitModelTest()">
                Run Test
                <span id="modelTestLoading" class="model-test-loading">⏳ Processing...</span>
              </button>
            </div>

            <div id="modelTestError" class="model-test-error"></div>
            <div id="modelTestResponse" class="model-test-response">
              <h3 class="model-test-response-title">Response:</h3>
              <div class="model-test-tabs">
                <button id="model-test-markdown-tab" class="model-test-tab model-test-tab-active" type="button">Markdown</button>
                <button id="model-test-raw-tab" class="model-test-tab" type="button">Raw</button>
              </div>
              <div class="model-test-tab-content">
                <div id="model-test-markdown-content" class="model-test-response-content model-test-tab-pane model-test-tab-pane-active"></div>
                <div id="model-test-raw-content" class="model-test-response-content model-test-tab-pane" style="display: none;">
                  <pre id="model-test-raw-text" class="model-test-raw-text"></pre>
                </div>
              </div>
              <div id="modelTestStats" class="model-test-stats"></div>
            </div>
          </form>
        </div>
      </div>

      <script nonce="#{content_security_policy_nonce}">
        function openModelTestModal(aiLogId, query, model, promptKey) {
          const modal = document.getElementById('modelTestModal');
          const queryField = document.getElementById('modelTestQuery');
          const modelSelect = document.getElementById('modelTestModelSelect');

          // Populate query field
          queryField.value = query;

          // Populate model dropdown if not already done
          if (modelSelect.options.length <= 1) {
            const models = #{model_dropdown_options_for_js.to_json};
            models.forEach(function(m) {
              const option = document.createElement('option');
              option.value = m.id;
              option.textContent = m.name;
              modelSelect.appendChild(option);
            });
          }

          // Set current model as selected
          modelSelect.value = model;

          // Store AI Log ID and prompt key for submission
          document.getElementById('modelTestForm').dataset.aiLogId = aiLogId;
          document.getElementById('modelTestForm').dataset.promptKey = promptKey;

          // Clear previous response
          document.getElementById('modelTestResponse').classList.remove('show');
          document.getElementById('modelTestError').classList.remove('show');

          // Show modal
          modal.classList.add('show');
        }

        function closeModelTestModal() {
          const modal = document.getElementById('modelTestModal');
          modal.classList.remove('show');
        }

        function submitModelTest() {
          const form = document.getElementById('modelTestForm');
          const model = document.getElementById('modelTestModelSelect').value;
          const query = document.getElementById('modelTestQuery').value;
          const promptKey = form.dataset.promptKey;
          const submitBtn = document.getElementById('modelTestSubmitBtn');
          const loadingSpinner = document.getElementById('modelTestLoading');
          const errorDiv = document.getElementById('modelTestError');
          const responseDiv = document.getElementById('modelTestResponse');

          if (!model || !query) {
            errorDiv.textContent = 'Please fill in all fields';
            errorDiv.classList.add('show');
            return;
          }

          // Show loading state
          submitBtn.disabled = true;
          loadingSpinner.classList.add('show');
          errorDiv.classList.remove('show');
          responseDiv.classList.remove('show');

          // Make AJAX request
          const xhr = new XMLHttpRequest();
          xhr.open('POST', '/admin/ai_logs/model_test', true);
          xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
          xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');

          // Get CSRF token
          const csrfToken = document.querySelector('meta[name="csrf-token"]');
          if (csrfToken) {
            xhr.setRequestHeader('X-CSRF-Token', csrfToken.getAttribute('content'));
          }

          xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
              submitBtn.disabled = false;
              loadingSpinner.classList.remove('show');

              if (xhr.status === 200) {
                try {
                  const response = JSON.parse(xhr.responseText);
                  displayModelTestResponse(response);
                } catch (e) {
                  errorDiv.textContent = 'Error parsing server response';
                  errorDiv.classList.add('show');
                }
              } else {
                let errorMessage = 'An error occurred while processing the request.';
                try {
                  const errorResponse = JSON.parse(xhr.responseText);
                  if (errorResponse.error) {
                    errorMessage = errorResponse.error;
                  }
                } catch (e) {
                  // Use default error message
                }
                errorDiv.textContent = errorMessage;
                errorDiv.classList.add('show');
              }
            }
          };

          const formData = 'model=' + encodeURIComponent(model) + '&query=' + encodeURIComponent(query) + '&prompt_key=' + encodeURIComponent(promptKey || '');
          xhr.send(formData);
        }

        function displayModelTestResponse(data) {
          const responseDiv = document.getElementById('modelTestResponse');
          const markdownContent = document.getElementById('model-test-markdown-content');
          const rawText = document.getElementById('model-test-raw-text');
          const statsDiv = document.getElementById('modelTestStats');

          // Populate markdown tab
          if (markdownContent) {
            if (data.markdown_html) {
              markdownContent.innerHTML = data.markdown_html;
            } else if (data.response) {
              markdownContent.textContent = data.response;
            }
          }

          // Populate raw tab
          if (rawText && data.response) {
            rawText.textContent = data.response;
          }

          // Build stats HTML
          let statsHtml = '';

          if (data.model) {
            statsHtml += '<div class="model-test-stat-item">' +
              '<div class="model-test-stat-label">Model</div>' +
              '<div class="model-test-stat-value">' + data.model + '</div>' +
              '</div>';
          }

          if (data.processing_time !== undefined) {
            statsHtml += '<div class="model-test-stat-item">' +
              '<div class="model-test-stat-label">Processing Time</div>' +
              '<div class="model-test-stat-value">' + data.processing_time + 'ms</div>' +
              '</div>';
          }

          if (data.input_tokens !== undefined) {
            statsHtml += '<div class="model-test-stat-item">' +
              '<div class="model-test-stat-label">Input Tokens</div>' +
              '<div class="model-test-stat-value">' + data.input_tokens + '</div>' +
              '</div>';
          }

          if (data.output_tokens !== undefined) {
            statsHtml += '<div class="model-test-stat-item">' +
              '<div class="model-test-stat-label">Output Tokens</div>' +
              '<div class="model-test-stat-value">' + data.output_tokens + '</div>' +
              '</div>';
          }

          if (data.input_tokens !== undefined && data.output_tokens !== undefined) {
            const totalTokens = data.input_tokens + data.output_tokens;
            statsHtml += '<div class="model-test-stat-item">' +
              '<div class="model-test-stat-label">Total Tokens</div>' +
              '<div class="model-test-stat-value">' + totalTokens + '</div>' +
              '</div>';
          }

          statsDiv.innerHTML = statsHtml;
          responseDiv.classList.add('show');
          setupModelTestTabs();
        }

        function setupModelTestTabs() {
          const markdownTab = document.getElementById('model-test-markdown-tab');
          const rawTab = document.getElementById('model-test-raw-tab');
          const markdownContent = document.getElementById('model-test-markdown-content');
          const rawContent = document.getElementById('model-test-raw-content');

          if (markdownTab && rawTab && markdownContent && rawContent) {
            markdownTab.addEventListener('click', function() {
              // Switch to markdown tab
              markdownTab.classList.add('model-test-tab-active');
              rawTab.classList.remove('model-test-tab-active');
              markdownContent.classList.add('model-test-tab-pane-active');
              rawContent.classList.remove('model-test-tab-pane-active');
              markdownContent.style.display = 'block';
              rawContent.style.display = 'none';
            });

            rawTab.addEventListener('click', function() {
              // Switch to raw tab
              rawTab.classList.add('model-test-tab-active');
              markdownTab.classList.remove('model-test-tab-active');
              rawContent.classList.add('model-test-tab-pane-active');
              markdownContent.classList.remove('model-test-tab-pane-active');
              rawContent.style.display = 'block';
              markdownContent.style.display = 'none';
            });
          }
        }

        // Close modal when clicking outside of it
        document.addEventListener('DOMContentLoaded', function() {
          const modal = document.getElementById('modelTestModal');
          window.addEventListener('click', function(event) {
            if (event.target === modal) {
              closeModelTestModal();
            }
          });
        });
      </script>
    HTML
  end
end
