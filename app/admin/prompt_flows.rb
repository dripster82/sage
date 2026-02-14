# frozen_string_literal: true

ActiveAdmin.register PromptFlow do
  menu parent: 'Ai Admin'

  permit_params :name, :description, :status, :version_number, :is_current, :max_executions

  config.batch_actions = false

  controller do
    def create
      @prompt_flow = PromptFlow.new(permitted_params[:prompt_flow])
      @prompt_flow.created_by = current_admin_user
      @prompt_flow.updated_by = current_admin_user

      if @prompt_flow.save
        redirect_to admin_prompt_flow_path(@prompt_flow), notice: 'Prompt flow was successfully created.'
      else
        render :new
      end
    end

    def update
      @prompt_flow = resource
      @prompt_flow.updated_by = current_admin_user

      if @prompt_flow.update(permitted_params[:prompt_flow])
        redirect_to admin_prompt_flow_path(@prompt_flow), notice: 'Prompt flow was successfully updated.'
      else
        render :edit
      end
    end
  end

  index do
    selectable_column
    id_column
    column :name
    column :status do |flow|
      status_tag flow.status
    end
    column :version_number
    column :max_executions
    column :updated_at
    actions
  end

  filter :name
  filter :status, as: :select, collection: %w[draft valid invalid]
  filter :is_current
  filter :updated_at

  form do |f|
    f.inputs do
      f.input :name
      f.input :description, as: :string
      f.input :status, as: :select, collection: %w[draft valid invalid]
      f.input :max_executions
    end

    panel 'Flow Canvas' do
      div id: 'prompt-flow-canvas',
          data: { editable: true },
          style: 'height: 600px; border: 1px solid #e5e7eb; position: relative;' do
        span 'Canvas will render here once jsPlumb is initialized.', class: 'text-gray-500'
      end

      script type: 'text/javascript' do
        raw <<~JS
          (function() {
            var canvas = document.getElementById('prompt-flow-canvas');
            if (!canvas || typeof window.jsPlumb === 'undefined') { return; }

            window.promptFlowInstance = window.jsPlumb.getInstance({
              Connector: ['Flowchart', { stub: [40, 60], gap: 10, cornerRadius: 5 }],
              Endpoint: ['Dot', { radius: 6 }],
              Container: canvas
            });
          })();
        JS
      end
    end

    f.actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :description
      row :status do |flow|
        status_tag flow.status
      end
      row :version_number
      row :max_executions
      row :created_by
      row :updated_by
      row :created_at
      row :updated_at
    end

    panel 'Flow Canvas (Read-Only)' do
      div id: 'prompt-flow-canvas',
          data: { editable: false },
          style: 'height: 600px; border: 1px solid #e5e7eb; position: relative;' do
        span 'Canvas will render here once jsPlumb is initialized.', class: 'text-gray-500'
      end

      script type: 'text/javascript' do
        raw <<~JS
          (function() {
            var canvas = document.getElementById('prompt-flow-canvas');
            if (!canvas || typeof window.jsPlumb === 'undefined') { return; }

            var instance = window.jsPlumb.getInstance({
              Connector: ['Flowchart', { stub: [40, 60], gap: 10, cornerRadius: 5 }],
              Endpoint: ['Dot', { radius: 6 }],
              Container: canvas
            });

            instance.setSuspendDrawing(true);
            instance.setDraggable(canvas.querySelectorAll('.prompt-flow-node'), false);
            instance.setSuspendDrawing(false, true);
          })();
        JS
      end
    end
  end
end
