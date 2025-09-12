# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Test Page', type: :feature do
  let(:admin_user) { create(:admin_user) }
  let!(:allowed_model) { create(:allowed_model, model: 'x-ai/grok-code-fast-1', name: 'Grok Code Fast', provider: 'x-ai', context_size: 128000, active: true, default: true) }
  let!(:allowed_model_2) { create(:allowed_model, model: 'openai/gpt-4o', name: 'GPT-4o', provider: 'openai', context_size: 128000, active: true, default: false) }
  let!(:allowed_model_3) { create(:allowed_model, model: 'anthropic/claude-3-5-sonnet', name: 'Claude 3.5 Sonnet', provider: 'anthropic', context_size: 200000, active: true, default: false) }
  let!(:prompt) { create(:prompt, name: 'test_prompt', tags: ['text', 'topic'].to_json, status: 'active') }

  before do
    # Sign in using Devise test helpers with scope
    sign_in admin_user, scope: :admin_user

    # Navigate to AI Test page directly
    visit '/admin/ai_test'
  end

  describe 'Page Loading' do
    it 'loads the AI Test page without errors' do
      expect(page).to have_content('AI Prompt Testing')
      expect(page).to have_select('prompt-select')
      expect(page).to have_button('Test Prompt')
    end

    it 'has proper styling applied' do
      # Check that the main container has the expected styling class
      expect(page).to have_css('.ai-test-container')
      expect(page).to have_css('.ai-test-title')
      expect(page).to have_css('.ai-test-form')
    end

    it 'shows prompt options' do
      # Should show the test prompt in the dropdown
      expect(page).to have_select('prompt-select', with_options: [prompt.name])
    end

    it 'initially hides model selection and tag fields' do
      # Model selection should be hidden initially
      expect(page).to have_css('#model-selection.ai-test-hidden')

      # Tag fields should be hidden initially
      expect(page).to have_css('#tag-fields.ai-test-hidden')
    end
  end

  describe 'Basic Form Elements' do
    it 'has model selection dropdown with options' do
      # Model selection should have allowed models in the custom dropdown
      within '#model-selection' do
        expect(page).to have_css('#model-search')
        expect(page).to have_css('#model-select', visible: false) # Hidden input
        expect(page).to have_css('.dropdown-item[data-value="x-ai/grok-code-fast-1"]')
      end
    end

    it 'has proper form structure' do
      # Check form elements exist
      expect(page).to have_css('#ai-test-form')
      expect(page).to have_css('#prompt-select')
      expect(page).to have_css('#model-select', visible: false) # Hidden input field
      expect(page).to have_css('#model-search') # Visible search input
      expect(page).to have_css('#tag-fields')
      expect(page).to have_css('#submit-btn')
    end
  end

  describe 'Page Structure' do
    it 'has response and error containers' do
      # Check response container exists but is hidden
      expect(page).to have_css('#response-container')
      expect(page).to have_css('#error-container')
    end

    it 'includes necessary CSS and JavaScript resources' do
      # Check that the page has proper nonce for CSP
      expect(page.html).to include('nonce=')

      # Check that basic JavaScript is loaded
      expect(page.html).to include('active_admin')
    end

    it 'has proper CSS classes for styling' do
      # Check that our custom CSS classes are present in the actual elements
      expect(page).to have_css('.ai-test-container')
      expect(page).to have_css('.ai-test-hidden')
      expect(page).to have_css('.ai-test-title')
    end

    it 'has response metadata container with grid layout CSS' do
      expect(page).to have_css('#response-meta.ai-test-response-meta')

      # Check that the grid layout CSS is present
      expect(page.html).to include('grid-template-columns: repeat(auto-fit, minmax(150px, 250px))')
      expect(page.html).to include('.ai-test-meta-item')
      expect(page.html).to include('.ai-test-meta-label')
      expect(page.html).to include('.ai-test-meta-value')
    end
  end

  describe 'Model Dropdown Issues' do
    it 'populates dropdown with all available models' do
      # Check that dropdown contains model options
      within '#model-dropdown' do
        expect(page).to have_css('.dropdown-item', count: AllowedModel.active.count)

        AllowedModel.active.each do |model|
          expect(page).to have_css(".dropdown-item[data-value='#{model.model}']")
          expect(page).to have_content("#{model.name} (#{model.provider}) - #{model.context_size} tokens")
        end
      end
    end

    it 'shows dropdown options with correct data attributes' do
      within '#model-dropdown' do
        allowed_model = AllowedModel.active.first
        dropdown_item = page.find(".dropdown-item[data-value='#{allowed_model.model}']")

        expect(dropdown_item['data-value']).to eq(allowed_model.model)
        expect(dropdown_item['data-provider']).to eq(allowed_model.provider)
        expect(dropdown_item['data-context']).to eq(allowed_model.context_size.to_s)
      end
    end

    it 'displays model information correctly in dropdown items' do
      within '#model-dropdown' do
        AllowedModel.active.each do |model|
          expected_text = "#{model.name} (#{model.provider}) - #{model.context_size} tokens"
          expect(page).to have_content(expected_text)
        end
      end
    end

    it 'has dropdown initially hidden' do
      expect(page).to have_css('#model-dropdown.dropdown', visible: true) # Container visible
      expect(page).not_to have_css('#model-dropdown.show') # But not showing (no .show class)
    end

    it 'contains search input field' do
      within '#model-selection' do
        search_input = page.find('#model-search')
        expect(search_input['type']).to eq('text')
        expect(search_input['placeholder']).to eq('Search and select a model...')
        expect(search_input['autocomplete']).to eq('off')
      end
    end

    it 'contains hidden model value field' do
      within '#model-selection' do
        hidden_input = page.find('#model-select', visible: false)
        expect(hidden_input['type']).to eq('hidden')
        expect(hidden_input['name']).to eq('model_id')
      end
    end
  end

  describe 'Model Preselection Issues' do
    it 'includes JavaScript for model preselection' do
      # Check that the setModelValue function is present
      expect(page.html).to include('function setModelValue(modelValue)')
      expect(page.html).to include('setModelValue(selectedPrompt.effective_model)')
    end

    it 'includes prompt data with effective models' do
      # Verify promptsData includes effective_model for each prompt
      expect(page.html).to include('var promptsData')
      expect(page.html).to include('effective_model')

      # Check that the prompt data includes our test prompt
      expect(page.html).to include(prompt.id.to_s)
      expect(page.html).to include(prompt.effective_model) if prompt.effective_model
    end

    it 'has console logging for debugging model selection' do
      # Verify debugging code is present
      expect(page.html).to include('console.log(\'Setting model dropdown to:\'')
      expect(page.html).to include('console.log(\'Found prompt:\'')
      expect(page.html).to include('console.log(\'Setting model value to:\'')
    end

    it 'shows the effective model in prompt data' do
      # Check that our test prompt has an effective model
      expect(prompt.effective_model).not_to be_nil
      expect(prompt.effective_model).to eq('x-ai/grok-code-fast-1') # Should be the default model
    end

    it 'has dropdown item for the effective model' do
      effective_model = prompt.effective_model
      if effective_model
        expect(page).to have_css(".dropdown-item[data-value='#{effective_model}']")

        # Check the text content of that dropdown item
        dropdown_item = page.find(".dropdown-item[data-value='#{effective_model}']")
        expect(dropdown_item.text).to include('Grok Code Fast')
      end
    end
  end

  describe 'JavaScript Functionality Tests', js: true do
    it 'shows model dropdown when prompt is selected' do
      # Initially model selection should be hidden
      expect(page).to have_css('#model-selection.ai-test-hidden')

      # Select a prompt
      select prompt.name, from: 'prompt-select'

      # Model selection should become visible
      expect(page).to have_css('#model-selection', visible: true)
      expect(page).not_to have_css('#model-selection.ai-test-hidden')
    end

    it 'preselects the effective model when prompt is selected' do
      # Select a prompt
      select prompt.name, from: 'prompt-select'

      # Wait for JavaScript to process
      sleep 0.5

      # Check if the model search field shows the preselected model
      effective_model = prompt.effective_model
      if effective_model
        # Find the dropdown item for this model
        expected_text = page.find(".dropdown-item[data-value='#{effective_model}']").text
        expect(page.find('#model-search').value).to eq(expected_text)
        expect(page.find('#model-select', visible: false).value).to eq(effective_model)
      end
    end

    it 'filters dropdown items when searching' do
      # Show the model dropdown first
      select prompt.name, from: 'prompt-select'

      # Type in the search field
      fill_in 'model-search', with: 'Grok'

      # Wait for filtering
      sleep 0.2

      # Should show dropdown with filtered results
      expect(page).to have_css('#model-dropdown.show')

      # Should show items containing "Grok"
      within '#model-dropdown' do
        expect(page).to have_content('Grok Code Fast')
        expect(page).not_to have_content('GPT-4o')
        expect(page).not_to have_content('Claude')
      end
    end

    it 'selects model when dropdown item is clicked' do
      # Show the model dropdown
      select prompt.name, from: 'prompt-select'

      # Click on the search field to show dropdown
      find('#model-search').click

      # Wait for dropdown to appear
      sleep 0.2

      # Click on a specific model
      within '#model-dropdown' do
        find('.dropdown-item[data-value="openai/gpt-4o"]').click
      end

      # Check that the model was selected
      expect(page.find('#model-search').value).to include('GPT-4o')
      expect(page.find('#model-select', visible: false).value).to eq('openai/gpt-4o')
    end

    it 'shows dropdown when search field is clicked even when empty' do
      # Show the model dropdown
      select prompt.name, from: 'prompt-select'

      # Initially dropdown should not be showing
      expect(page).not_to have_css('#model-dropdown.show')

      # Click on empty search field
      find('#model-search').click

      # Wait for dropdown to show
      sleep 0.2

      # Dropdown should now be visible with all options
      expect(page).to have_css('#model-dropdown.show')
      within '#model-dropdown' do
        expect(page).to have_content('Grok Code Fast')
        expect(page).to have_content('GPT-4o')
        expect(page).to have_content('Claude')
      end
    end

    it 'hides dropdown when clicking outside' do
      # Show the model dropdown
      select prompt.name, from: 'prompt-select'
      find('#model-search').click

      # Wait for dropdown to show
      sleep 0.2
      expect(page).to have_css('#model-dropdown.show')

      # Click outside the dropdown
      find('body').click

      # Dropdown should be hidden
      sleep 0.2
      expect(page).not_to have_css('#model-dropdown.show')
    end
  end

  describe 'End-to-End Workflow (Manual Testing Required)' do
    it 'has all necessary elements for manual testing' do
      # Verify that all the elements needed for manual testing are present
      expect(page).to have_content('AI Prompt Testing')
      expect(page).to have_select('prompt-select')
      expect(page).to have_css('#model-selection.ai-test-hidden') # Initially hidden
      expect(page).to have_css('#tag-fields.ai-test-hidden') # Initially hidden
      expect(page).to have_button('Test Prompt')
      expect(page).to have_css('#response-container')
      expect(page).to have_css('#error-container')
    end

    it 'contains JavaScript for dynamic functionality' do
      # Verify that the JavaScript code is present for manual testing
      expect(page.html).to include('promptsData')
      expect(page.html).to include('setupSearchableDropdown')
      expect(page.html).to include('setModelValue')
      expect(page.html).to include('addEventListener')
    end

    it 'has proper form structure for AJAX submission' do
      # Verify the form is set up for AJAX processing
      expect(page).to have_css('form#ai-test-form')
      expect(page).to have_css('#submit-btn[type="button"]') # Button, not submit
      expect(page.html).to include('/admin/ai_test/process_prompt') # AJAX endpoint
    end

    it 'shows available prompts and models' do
      # Verify data is loaded
      expect(page).to have_select('prompt-select', with_options: [prompt.name])
      expect(page).to have_css('.dropdown-item[data-value="x-ai/grok-code-fast-1"]')
    end
  end


end
