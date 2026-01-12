# frozen_string_literal: true

ActiveAdmin.register_page "AI Test" do
  menu parent: "Ai Admin"

  page_action :process_prompt, method: :post

  content title: "AI Test" do
    # Add CSS styles directly to the page
    text_node raw(<<~HTML)
      <style nonce="#{content_security_policy_nonce}">
        /* Custom searchable select styling */
        .ai-test-searchable-select {
          position: relative;
          width: 100%;
        }

        #model-search {
          width: 100%;
          padding: 8px 12px;
          border: 1px solid #d1d5db;
          border-radius: 6px;
          background-color: white;
          color: #374151;
          font-size: 14px;
        }

        .dark #model-search {
          background-color: #374151;
          border-color: #4b5563;
          color: #f9fafb;
        }

        #model-search:focus {
          outline: none;
          border-color: #3b82f6;
          box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
        }

        .dropdown {
          position: absolute;
          top: 100%;
          left: 0;
          right: 0;
          background: white;
          border: 1px solid #d1d5db;
          border-top: none;
          border-radius: 0 0 6px 6px;
          max-height: 200px;
          overflow-y: auto;
          z-index: 1000;
          display: none;
        }

        .dark .dropdown {
          background-color: #374151;
          border-color: #4b5563;
        }

        .dropdown.show {
          display: block;
        }

        .dropdown-item {
          padding: 8px 12px;
          cursor: pointer;
          border-bottom: 1px solid #f3f4f6;
          font-size: 14px;
          color: #374151;
        }

        .dark .dropdown-item {
          border-bottom-color: #4b5563;
          color: #f9fafb;
        }

        .dropdown-item:hover {
          background-color: #f3f4f6;
        }

        .dark .dropdown-item:hover {
          background-color: #4b5563;
        }

        .dropdown-item.selected {
          background-color: #3b82f6;
          color: white;
        }

        .dropdown-item:last-child {
          border-bottom: none;
        }

        /* AI Test Page Styling */
        .ai-test-container {
          max-width: 800px;
          margin: 0 auto;
          padding: 20px;
          background: white;
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }

        .dark .ai-test-container {
          background: #1f2937;
          box-shadow: 0 2px 4px rgba(0, 0, 0, 0.3);
        }

        .ai-test-title {
          font-size: 24px;
          font-weight: bold;
          margin-bottom: 20px;
          color: #1f2937;
        }

        .dark .ai-test-title {
          color: #f9fafb;
        }

        .ai-test-form {
          display: flex;
          flex-direction: column;
          gap: 16px;
        }

        .ai-test-field {
          display: flex;
          flex-direction: column;
          gap: 8px;
        }

        .ai-test-label {
          font-weight: 600;
          color: #374151;
          font-size: 14px;
        }

        .dark .ai-test-label {
          color: #d1d5db;
        }

        .ai-test-select, .ai-test-input, .ai-test-textarea {
          padding: 8px 12px;
          border: 1px solid #d1d5db;
          border-radius: 6px;
          font-size: 14px;
          background-color: white;
          color: #374151;
        }

        .dark .ai-test-select, .dark .ai-test-input, .dark .ai-test-textarea {
          background-color: #374151;
          border-color: #4b5563;
          color: #f9fafb;
        }

        .ai-test-select:focus, .ai-test-input:focus, .ai-test-textarea:focus {
          outline: none;
          border-color: #3b82f6;
          box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
        }

        .ai-test-textarea {
          min-height: 80px;
          resize: vertical;
          font-family: inherit;
        }

        .ai-test-button {
          padding: 10px 20px;
          background-color: #3b82f6;
          color: white;
          border: none;
          border-radius: 6px;
          font-size: 14px;
          font-weight: 600;
          cursor: pointer;
          transition: background-color 0.2s;
        }

        .ai-test-button:hover {
          background-color: #2563eb;
        }

        .ai-test-button:disabled {
          background-color: #9ca3af;
          cursor: not-allowed;
        }

        .ai-test-loading {
          display: none;
          margin-left: 10px;
          color: #6b7280;
          font-size: 14px;
        }

        .ai-test-loading.ai-test-show {
          display: inline;
        }

        .ai-test-hidden {
          display: none;
        }

        .ai-test-response {
          margin-top: 20px;
          padding: 16px;
          background-color: #f9fafb;
          border-radius: 6px;
          border: 1px solid #e5e7eb;
        }

        .dark .ai-test-response {
          background-color: #374151;
          border-color: #4b5563;
        }

        .ai-test-response-title {
          font-size: 18px;
          font-weight: 600;
          margin-bottom: 12px;
          color: #1f2937;
        }

        .dark .ai-test-response-title {
          color: #f9fafb;
        }

        .ai-test-response-content {
          margin-bottom: 12px;
          line-height: 1.6;
          color: #374151;
        }

        .dark .ai-test-response-content {
          color: #d1d5db;
        }

        .ai-test-response-meta {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
          gap: 16px;
          font-size: 12px;
          color: #6b7280;
          border-top: 1px solid #e5e7eb;
          padding-top: 16px;
          margin-top: 16px;
        }

        @media (max-width: 768px) {
          .ai-test-response-meta {
            grid-template-columns: 1fr;
          }
        }

        .dark .ai-test-response-meta {
          color: #9ca3af;
          border-top-color: #4b5563;
        }

        .ai-test-meta-item {
          background: #f9fafb;
          padding: 12px;
          border-radius: 6px;
          border-left: 4px solid #3b82f6;
        }

        .dark .ai-test-meta-item {
          background: #374151;
          border-left-color: #60a5fa;
        }

        .ai-test-meta-label {
          font-size: 11px;
          font-weight: 600;
          text-transform: uppercase;
          letter-spacing: 0.05em;
          color: #6b7280;
          margin-bottom: 4px;
        }

        .dark .ai-test-meta-label {
          color: #9ca3af;
        }

        .ai-test-meta-value {
          font-size: 14px;
          font-weight: 500;
          color: #1f2937;
        }

        .dark .ai-test-meta-value {
          color: #f9fafb;
        }

        /* Tab styling */
        .ai-test-tabs {
          display: flex;
          border-bottom: 2px solid #e9ecef;
          margin-bottom: 15px;
          gap: 0;
        }

        .dark .ai-test-tabs {
          border-bottom-color: #4b5563;
        }

        .ai-test-tab {
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

        .ai-test-tab:hover {
          color: #374151;
          background-color: #f9fafb;
        }

        .ai-test-tab-active {
          color: #3b82f6 !important;
          border-bottom-color: #3b82f6 !important;
          background-color: transparent !important;
        }

        .dark .ai-test-tab {
          color: #9ca3af;
        }

        .dark .ai-test-tab:hover {
          color: #f3f4f6;
          background-color: #374151;
        }

        .dark .ai-test-tab-active {
          color: #60a5fa !important;
          border-bottom-color: #60a5fa !important;
        }

        .ai-test-tab-content {
          position: relative;
        }

        .ai-test-tab-pane {
          display: none;
        }

        .ai-test-tab-pane-active {
          display: block !important;
        }

        .ai-test-raw-text {
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

        .dark .ai-test-raw-text {
          background-color: #1f2937;
          border-color: #374151;
          color: #f3f4f6;
        }

        /* Markdown content styling */
        #markdown-content h1 {
          font-size: 24px;
          font-weight: 700;
          color: #1f2937;
          margin: 20px 0 16px 0;
          padding-bottom: 8px;
          border-bottom: 2px solid #e5e7eb;
        }

        #markdown-content h2 {
          font-size: 20px;
          font-weight: 600;
          color: #374151;
          margin: 18px 0 14px 0;
          padding-bottom: 6px;
          border-bottom: 1px solid #e5e7eb;
        }

        #markdown-content h3 {
          font-size: 18px;
          font-weight: 600;
          color: #374151;
          margin: 16px 0 12px 0;
        }

        #markdown-content h4, #markdown-content h5, #markdown-content h6 {
          font-size: 16px;
          font-weight: 600;
          color: #4b5563;
          margin: 14px 0 10px 0;
        }

        #markdown-content p {
          margin: 12px 0;
          line-height: 1.6;
          color: #374151;
        }

        #markdown-content strong {
          font-weight: 700;
          color: #1f2937;
        }

        #markdown-content em {
          font-style: italic;
          color: #4b5563;
        }

        #markdown-content code {
          background-color: #f3f4f6;
          border: 1px solid #e5e7eb;
          border-radius: 4px;
          padding: 2px 6px;
          font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
          font-size: 13px;
          color: #dc2626;
        }

        #markdown-content pre {
          background-color: #f8f9fa;
          border: 1px solid #e5e7eb;
          border-radius: 6px;
          padding: 16px;
          margin: 16px 0;
          overflow-x: auto;
          font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
          font-size: 13px;
          line-height: 1.4;
        }

        #markdown-content pre code {
          background: none;
          border: none;
          padding: 0;
          color: #374151;
        }

        #markdown-content ul, #markdown-content ol {
          margin: 12px 0;
          padding-left: 24px;
        }

        #markdown-content li {
          margin: 6px 0;
          line-height: 1.5;
          color: #374151;
        }

        #markdown-content blockquote {
          border-left: 4px solid #e5e7eb;
          padding-left: 16px;
          margin: 16px 0;
          color: #6b7280;
          font-style: italic;
        }

        #markdown-content table {
          border-collapse: collapse;
          width: 100%;
          margin: 16px 0;
        }

        #markdown-content th, #markdown-content td {
          border: 1px solid #e5e7eb;
          padding: 8px 12px;
          text-align: left;
        }

        #markdown-content th {
          background-color: #f9fafb;
          font-weight: 600;
        }

        #markdown-content a {
          color: #3b82f6;
          text-decoration: underline;
          text-underline-offset: 2px;
        }

        #markdown-content a:hover {
          color: #1d4ed8;
          text-decoration-thickness: 2px;
        }

        #markdown-content hr {
          border: none;
          border-top: 2px solid #e5e7eb;
          margin: 24px 0;
        }

        #markdown-content del {
          text-decoration: line-through;
          color: #6b7280;
        }

        #markdown-content ul {
          list-style-type: disc;
        }

        #markdown-content ol {
          list-style-type: decimal;
        }

        #markdown-content tbody tr:nth-child(even) {
          background-color: #f9fafb;
        }

        /* Dark mode styles for markdown content */
        .dark #markdown-content h1 {
          color: #f9fafb;
          border-bottom-color: #4b5563;
        }

        .dark #markdown-content h2 {
          color: #f3f4f6;
          border-bottom-color: #4b5563;
        }

        .dark #markdown-content h3,
        .dark #markdown-content h4,
        .dark #markdown-content h5,
        .dark #markdown-content h6 {
          color: #f3f4f6;
        }

        .dark #markdown-content p,
        .dark #markdown-content li {
          color: #d1d5db;
        }

        .dark #markdown-content strong {
          color: #f9fafb;
        }

        .dark #markdown-content em {
          color: #9ca3af;
        }

        .dark #markdown-content code {
          background-color: #374151;
          border-color: #4b5563;
          color: #fbbf24;
        }

        .dark #markdown-content pre {
          background-color: #1f2937;
          border-color: #374151;
        }

        .dark #markdown-content pre code {
          color: #d1d5db;
          background: none;
        }

        .dark #markdown-content blockquote {
          border-left-color: #4b5563;
          color: #9ca3af;
        }

        .dark #markdown-content th,
        .dark #markdown-content td {
          border-color: #4b5563;
        }

        .dark #markdown-content th {
          background-color: #374151;
        }

        .dark #markdown-content a {
          color: #60a5fa;
        }

        .dark #markdown-content a:hover {
          color: #93c5fd;
        }

        .dark #markdown-content hr {
          border-top-color: #4b5563;
        }

        .dark #markdown-content del {
          color: #9ca3af;
        }

        .dark #markdown-content tbody tr:nth-child(even) {
          background-color: #374151;
        }

        .ai-test-error {
          margin-top: 20px;
          padding: 12px;
          background-color: #fef2f2;
          border: 1px solid #fecaca;
          border-radius: 6px;
          color: #dc2626;
          display: none;
        }

        .dark .ai-test-error {
          background-color: #7f1d1d;
          border-color: #dc2626;
          color: #fca5a5;
        }

        .ai-test-error.ai-test-show {
          display: block;
        }
      </style>
    HTML
    # Create a test prompt with tags if it doesn't exist
    unless Prompt.find_by(name: 'ai_test_sample')
      admin_user = AdminUser.first
      if admin_user
        Prompt.create!(
          name: 'ai_test_sample',
          content: 'Please analyze the following %{text} and provide insights about %{topic}. Focus on %{aspect} in your response.',
          description: 'Sample prompt for AI testing with multiple parameters',
          category: 'testing',
          status: 'active',
          created_by: admin_user,
          updated_by: admin_user
        )
      end
    end

    # Add basic styling
    div class: "ai-test-container" do
      h2 "AI Prompt Testing", class: "ai-test-title"

      # Form with proper styling
      form "", id: "ai-test-form", class: "ai-test-form" do
        # Prompt Selection
        div class: "ai-test-field" do
          label "Select Prompt:", class: "ai-test-label"
          select "", id: "prompt-select", name: "prompt_id", class: "ai-test-select" do
            option value: "" do
              "Choose a prompt..."
            end
            Prompt.active.order(:name).each do |prompt|
              option value: prompt.id do
                "#{prompt.name} - #{prompt.description&.truncate(50) || 'No description'}"
              end
            end
          end
        end

        # Model Selection (initially hidden)
        div "", id: "model-selection", class: "ai-test-field ai-test-hidden" do
          label "Select Model:", class: "ai-test-label"
          div "", class: "ai-test-searchable-select" do
            input "", type: "text", id: "model-search", placeholder: "Search and select a model...", autocomplete: "off"
            input "", type: "hidden", id: "model-select", name: "model_id"
            div "", id: "model-dropdown", class: "dropdown" do
              AllowedModel.active.order(:name).each do |model|
                div "#{model.name} (#{model.provider}) - #{model.context_size} tokens", class: "dropdown-item", "data-value": model.model, "data-provider": model.provider, "data-context": model.context_size
              end
            end
          end
        end

        # Dynamic tag fields container
        div "", id: "tag-fields", class: "ai-test-field ai-test-hidden"

        # Submit button
        div class: "ai-test-field" do
          button "Test Prompt", type: "button", id: "submit-btn", class: "ai-test-button"
          span "⏳ Processing...", id: "loading-spinner", class: "ai-test-loading"
        end
      end
    end

    # Response container with tabs
    div "", id: "response-container", class: "ai-test-response" do
      h3 "AI Response:", class: "ai-test-response-title"

      # Tab navigation
      div "", class: "ai-test-tabs" do
        button "Markdown", id: "markdown-tab", class: "ai-test-tab ai-test-tab-active", type: "button"
        button "Raw", id: "raw-tab", class: "ai-test-tab", type: "button"
      end

      # Tab content
      div "", class: "ai-test-tab-content" do
        div "", id: "markdown-content", class: "ai-test-response-content ai-test-tab-pane ai-test-tab-pane-active"
        div "", id: "raw-content", class: "ai-test-response-content ai-test-tab-pane", style: "display: none;" do
          pre "", id: "raw-text", class: "ai-test-raw-text"
        end
      end

      div "", id: "response-meta", class: "ai-test-response-meta"
    end

    # Error container
    div "", id: "error-container", class: "ai-test-error" do
      strong "Error: "
      span "", id: "error-message"
    end

    # No external dependencies - use vanilla JavaScript



    # JavaScript for dynamic functionality with CSP nonce
    text_node raw(<<~HTML)
      <script nonce="#{content_security_policy_nonce}">
        console.log('AI Test script loading...');

        // Prompt data for JavaScript
        var promptsData = #{Prompt.active.includes(:allowed_model).map { |p|
          {
            id: p.id,
            name: p.name,
            description: p.description,
            tags_list: p.tags_list,
            model_name: p.model_display_name,
            effective_model: p.effective_model
          }
        }.to_json};

        // Debug: Show prompts data in console
        console.log('Prompts loaded:', promptsData.length, 'prompts');
        console.log('All prompts data:', promptsData);
        promptsData.forEach(function(prompt, index) {
          console.log('Prompt ' + index + ':', prompt.name, 'Tags:', prompt.tags_list, 'Effective Model:', prompt.effective_model);
        });

        // Debug: Show available models in dropdown
        var modelOptions = document.querySelectorAll('#model-select option');
        console.log('Available models in dropdown:');
        modelOptions.forEach(function(option) {
          if (option.value) {
            console.log('- Model:', option.value, 'Text:', option.textContent);
          }
        });

        console.log('Prompts data loaded:', promptsData);

        // Wait for DOM to be ready
        document.addEventListener('DOMContentLoaded', function() {
          console.log('DOM ready, setting up AI Test...');

          var promptSelect = document.getElementById('prompt-select');
          var modelSelection = document.getElementById('model-selection');
          var modelSelect = document.getElementById('model-select');
          var modelSearch = document.getElementById('model-search');
          var modelDropdown = document.getElementById('model-dropdown');
          var tagFieldsContainer = document.getElementById('tag-fields');
          var submitBtn = document.getElementById('submit-btn');
          var loadingSpinner = document.getElementById('loading-spinner');
          var responseContainer = document.getElementById('response-container');
          var errorContainer = document.getElementById('error-container');

          // Setup searchable model dropdown
          setupSearchableDropdown();

          // Setup tabs
          setupTabs();

          // Handle prompt selection
          promptSelect.addEventListener('change', function() {
            var promptId = this.value;
            console.log('Prompt selected:', promptId);

            if (promptId) {
              var selectedPrompt = promptsData.find(function(p) { return p.id == promptId; });
              console.log('Found prompt:', selectedPrompt);

              // Show model selection
              modelSelection.classList.remove('ai-test-hidden');

              // Set the effective model in the searchable dropdown
              if (selectedPrompt.effective_model) {
                console.log('Setting model dropdown to:', selectedPrompt.effective_model);
                setModelValue(selectedPrompt.effective_model);
              }

              if (selectedPrompt && selectedPrompt.tags_list && selectedPrompt.tags_list.length > 0) {
                // Show tag fields
                console.log('Creating tag fields for:', selectedPrompt.tags_list);
                var fieldsHtml = '<h3 class="ai-test-response-title">Prompt Parameters:</h3>';

                selectedPrompt.tags_list.forEach(function(tag) {
                  console.log('Adding field for tag:', tag);
                  fieldsHtml += '<div class="ai-test-field">' +
                    '<label for="tag-' + tag + '" class="ai-test-label">' +
                    tag.charAt(0).toUpperCase() + tag.slice(1) + ':</label>' +
                    '<textarea id="tag-' + tag + '" name="tags[' + tag + ']" placeholder="Enter ' + tag + '..." rows="3" class="ai-test-textarea"></textarea>' +
                    '</div>';
                });

                console.log('Setting HTML:', fieldsHtml);
                tagFieldsContainer.innerHTML = fieldsHtml;
                tagFieldsContainer.classList.remove('ai-test-hidden');
              } else {
                console.log('No tags found or empty tags list');
                // Hide tag fields if no tags
                tagFieldsContainer.classList.add('ai-test-hidden');
              }
            } else {
              console.log('No prompt selected');
              modelSelection.classList.add('ai-test-hidden');
              tagFieldsContainer.classList.add('ai-test-hidden');
            }
          });

          // Handle form submission
          submitBtn.addEventListener('click', function(e) {
            e.preventDefault();
            console.log('Submit button clicked');

            var promptId = promptSelect.value;
            var selectedModel = modelSelect.value;
            console.log('Selected prompt ID:', promptId);
            console.log('Selected model:', selectedModel);

            if (!promptId) {
              alert('Please select a prompt first.');
              return;
            }

            // Collect tag values
            var tags = {};
            var tagInputs = document.querySelectorAll('textarea[name^="tags["]');
            tagInputs.forEach(function(input) {
              var tagName = input.name.match(/tags\\[(.+)\\]/)[1];
              tags[tagName] = input.value;
              console.log('Tag:', tagName, '=', input.value);
            });

            console.log('All tags:', tags);

            // Show loading state
            submitBtn.disabled = true;
            loadingSpinner.classList.add('ai-test-show');
            responseContainer.classList.add('ai-test-hidden');
            errorContainer.classList.add('ai-test-hidden');

            // Make AJAX request
            console.log('Making AJAX request to /admin/ai_test/process_prompt');
            var xhr = new XMLHttpRequest();
            xhr.open('POST', '/admin/ai_test/process_prompt', true);
            xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
            xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');

            // Get CSRF token
            var csrfToken = document.querySelector('meta[name="csrf-token"]');
            if (csrfToken) {
              xhr.setRequestHeader('X-CSRF-Token', csrfToken.getAttribute('content'));
            }

            xhr.onreadystatechange = function() {
              if (xhr.readyState === 4) {
                submitBtn.disabled = false;
                loadingSpinner.classList.remove('ai-test-show');

                if (xhr.status === 200) {
                  try {
                    var response = JSON.parse(xhr.responseText);
                    console.log('Success response:', response);
                    displayResponse(response);
                  } catch (e) {
                    console.log('Error parsing response:', e);
                    displayError('Error parsing server response');
                  }
                } else {
                  console.log('Error response:', xhr);
                  var errorMessage = 'An error occurred while processing the request.';
                  try {
                    var errorResponse = JSON.parse(xhr.responseText);
                    if (errorResponse.error) {
                      errorMessage = errorResponse.error;
                    }
                  } catch (e) {
                    // Use default error message
                  }
                  displayError(errorMessage);
                }
              }
            };

            // Prepare form data
            var formData = 'prompt_id=' + encodeURIComponent(promptId);
            if (selectedModel) {
              formData += '&model=' + encodeURIComponent(selectedModel);
            }
            for (var tagName in tags) {
              formData += '&tags[' + encodeURIComponent(tagName) + ']=' + encodeURIComponent(tags[tagName]);
            }

            xhr.send(formData);
          });

          function displayResponse(data) {
            console.log('Displaying response:', data);

            // Populate markdown tab
            var markdownContent = document.getElementById('markdown-content');
            if (markdownContent && data.markdown_html) {
              markdownContent.innerHTML = data.markdown_html;
            }

            // Populate raw tab
            var rawText = document.getElementById('raw-text');
            if (rawText && data.response) {
              rawText.textContent = data.response;
            }

            var metaHtml =
              '<div class="ai-test-meta-item">' +
                '<div class="ai-test-meta-label">Model Used</div>' +
                '<div class="ai-test-meta-value">' + data.model + '</div>' +
              '</div>' +
              '<div class="ai-test-meta-item">' +
                '<div class="ai-test-meta-label">Total Cost</div>' +
                '<div class="ai-test-meta-value">$' + (data.cost || '0.000') + '</div>' +
              '</div>' +
              '<div class="ai-test-meta-item">' +
                '<div class="ai-test-meta-label">Processing Time</div>' +
                '<div class="ai-test-meta-value">' + (data.processing_time || '0') + 'ms</div>' +
              '</div>' +
              '<div class="ai-test-meta-item">' +
                '<div class="ai-test-meta-label">Input Tokens</div>' +
                '<div class="ai-test-meta-value">' + (data.input_tokens || '0') + '</div>' +
              '</div>' +
              '<div class="ai-test-meta-item">' +
                '<div class="ai-test-meta-label">Output Tokens</div>' +
                '<div class="ai-test-meta-value">' + (data.output_tokens || '0') + '</div>' +
              '</div>' +
              '<div class="ai-test-meta-item">' +
                '<div class="ai-test-meta-label">AI Log ID</div>' +
                '<div class="ai-test-meta-value">' + data.ai_log_id + '</div>' +
              '</div>';

            document.getElementById('response-meta').innerHTML = metaHtml;
            responseContainer.classList.remove('ai-test-hidden');
          }

          function displayError(message) {
            console.log('Displaying error:', message);
            document.getElementById('error-message').textContent = message;
            errorContainer.classList.remove('ai-test-hidden');
          }

          function setupTabs() {
            console.log('Setting up tabs');
            var markdownTab = document.getElementById('markdown-tab');
            var rawTab = document.getElementById('raw-tab');
            var markdownContent = document.getElementById('markdown-content');
            var rawContent = document.getElementById('raw-content');

            if (markdownTab && rawTab && markdownContent && rawContent) {
              markdownTab.addEventListener('click', function() {
                // Switch to markdown tab
                markdownTab.classList.add('ai-test-tab-active');
                rawTab.classList.remove('ai-test-tab-active');
                markdownContent.classList.add('ai-test-tab-pane-active');
                rawContent.classList.remove('ai-test-tab-pane-active');
                markdownContent.style.display = 'block';
                rawContent.style.display = 'none';
              });

              rawTab.addEventListener('click', function() {
                // Switch to raw tab
                rawTab.classList.add('ai-test-tab-active');
                markdownTab.classList.remove('ai-test-tab-active');
                rawContent.classList.add('ai-test-tab-pane-active');
                markdownContent.classList.remove('ai-test-tab-pane-active');
                rawContent.style.display = 'block';
                markdownContent.style.display = 'none';
              });
            }
          }

          function setupSearchableDropdown() {
            console.log('Setting up searchable dropdown');

            // Handle search input
            modelSearch.addEventListener('input', function() {
              var searchTerm = this.value.toLowerCase();
              var items = modelDropdown.querySelectorAll('.dropdown-item');
              var hasVisibleItems = false;

              items.forEach(function(item) {
                var text = item.textContent.toLowerCase();
                var value = item.getAttribute('data-value').toLowerCase();

                if (text.indexOf(searchTerm) > -1 || value.indexOf(searchTerm) > -1) {
                  item.style.display = 'block';
                  hasVisibleItems = true;
                } else {
                  item.style.display = 'none';
                }
              });

              if (hasVisibleItems && searchTerm.length > 0) {
                modelDropdown.classList.add('show');
              } else {
                modelDropdown.classList.remove('show');
              }
            });

            // Handle focus to show dropdown
            modelSearch.addEventListener('focus', function() {
              // Show all items when focusing
              var items = modelDropdown.querySelectorAll('.dropdown-item');
              items.forEach(function(item) {
                item.style.display = 'block';
              });
              modelDropdown.classList.add('show');
            });

            // Handle click to show dropdown
            modelSearch.addEventListener('click', function() {
              // Show all items when clicking
              var items = modelDropdown.querySelectorAll('.dropdown-item');
              items.forEach(function(item) {
                item.style.display = 'block';
              });
              modelDropdown.classList.add('show');
            });

            // Handle click outside to hide dropdown
            document.addEventListener('click', function(e) {
              if (!modelSelection.contains(e.target)) {
                modelDropdown.classList.remove('show');
              }
            });

            // Handle item selection
            modelDropdown.addEventListener('click', function(e) {
              if (e.target.classList.contains('dropdown-item')) {
                var value = e.target.getAttribute('data-value');
                var text = e.target.textContent;

                modelSearch.value = text;
                modelSelect.value = value;
                modelDropdown.classList.remove('show');

                console.log('Model selected:', value);
              }
            });
          }

          function setModelValue(modelValue) {
            console.log('Setting model value to:', modelValue);
            var items = modelDropdown.querySelectorAll('.dropdown-item');
            var found = false;

            items.forEach(function(item) {
              if (item.getAttribute('data-value') === modelValue) {
                modelSearch.value = item.textContent;
                modelSelect.value = modelValue;
                item.classList.add('selected');
                found = true;
                console.log('Model found and set:', modelValue);
              } else {
                item.classList.remove('selected');
              }
            });

            if (!found) {
              console.log('ERROR: Model not found in dropdown:', modelValue);
            }
          }
        });
      </script>
    HTML
  end

  # Handle the form submission
  controller do
    def process_prompt
      begin
        # Set session for admin testing
        Current.ailog_session = "ADMIN_TEST"

        prompt = Prompt.find(params[:prompt_id])
        tags = params[:tags] || {}
        selected_model = params[:model]

        # Record start time
        start_time = Time.current

        # Process the prompt with optional model override
        service = PromptProcessingService.new(model: selected_model)
        result = service.process_and_query(
          prompt_key: prompt.name,
          query: tags[:query] || '',
          parameters: tags.except(:query)
        )

        # Calculate processing time
        processing_time = ((Time.current - start_time) * 1000).round(2)

        # Convert markdown to HTML
        markdown_html = render_markdown(result[:response].content)

        # Return JSON response
        render json: {
          response: result[:response].content,
          markdown_html: markdown_html,
          model: result[:ai_log].settings['model'],
          cost: sprintf('%.6f', result[:ai_log].total_cost || 0),
          processing_time: processing_time,
          input_tokens: result[:ai_log].input_tokens,
          output_tokens: result[:ai_log].output_tokens,
          ai_log_id: result[:ai_log].id
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

      # Use GitHub Markup for consistent markdown processing
      require 'github/markup'

      # Process markdown using GitHub's markup processor
      html = GitHub::Markup.render('README.md', text)

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
end
