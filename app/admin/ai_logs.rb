# frozen_string_literal: true

ActiveAdmin.register AiLog do
  menu parent: "Ai Admin"

  permit_params :model, :settings, :query, :response, :chat_id, :input_tokens, :output_tokens

  config.batch_actions = false

  index do
    selectable_column
    id_column
    column :model do |ai_log|
      ai_log.model_display_name
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
    column :created_at
    actions
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
end
