# frozen_string_literal: true

ActiveAdmin.register PromptFlow do
  menu parent: 'Ai Admin'

  permit_params :name, :description, :max_executions, :graph_json

  config.batch_actions = false

  controller do
    def scoped_collection
      base = super
      return base unless action_name == 'index'

      ranked = base.select(
        <<~SQL.squish
          prompt_flows.*,
          ROW_NUMBER() OVER (
            PARTITION BY prompt_flows.name
            ORDER BY prompt_flows.is_current DESC, prompt_flows.version_number DESC, prompt_flows.id DESC
          ) AS flow_rank
        SQL
      )

      PromptFlow.from("(#{ranked.to_sql}) prompt_flows").where('flow_rank = 1')
    end

    def create
      @prompt_flow = PromptFlow.new(permitted_params[:prompt_flow])
      @prompt_flow.is_current = false
      @prompt_flow.version_number = @prompt_flow.next_version_number
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

    def edit
      flow = resource
      if flow.is_current?
        existing_draft = PromptFlow.for_name(flow.name)
                                   .where(is_current: false, status: 'draft')
                                   .where('version_number > ?', flow.version_number)
                                   .order(version_number: :desc)
                                   .first
        if existing_draft
          redirect_to edit_admin_prompt_flow_path(existing_draft), notice: 'Opened existing draft version.'
        else
          draft = flow.duplicate_as_draft!(current_admin_user)
          redirect_to edit_admin_prompt_flow_path(draft), notice: 'Created a draft version for editing.'
        end
      else
        super
      end
    end
  end

  member_action :activate, method: :patch do
    flow = resource
    PromptFlow.transaction do
      PromptFlow.for_name(flow.name).where(is_current: true).where.not(id: flow.id).update_all(is_current: false)
      flow.update!(is_current: true, updated_by: current_admin_user)
      flow.sync_graph_to_nodes_and_edges!

      # Keep node/edge tables populated only for the active version.
      PromptFlow.for_name(flow.name).where.not(id: flow.id).find_each do |other_version|
        other_version.edges.delete_all
        other_version.nodes.delete_all
      end
    end

    redirect_to admin_prompt_flow_path(flow), notice: 'Prompt flow activated.'
  end

  member_action :duplicate, method: :post do
    draft = resource.duplicate_as_draft!(current_admin_user)
    redirect_to edit_admin_prompt_flow_path(draft), notice: 'Draft duplicated from selected version.'
  end

  member_action :test_execute, method: :post do
    flow = resource
    mode = params[:mode].to_s
    mode = 'evaluate' unless %w[simulate evaluate].include?(mode)
    graph_payload = params[:graph]
    graph_payload = graph_payload.to_unsafe_h if graph_payload.is_a?(ActionController::Parameters)
    inputs_payload = params[:inputs].is_a?(ActionController::Parameters) ? params[:inputs].to_unsafe_h : (params[:inputs] || {})

    result = nil
    validation_errors = []
    simulation_errors = []

    if mode == 'simulate'
      graph = graph_payload.presence || flow.graph_json
      if graph.is_a?(String)
        begin
          graph = JSON.parse(graph)
        rescue JSON::ParserError
          graph = {}
        end
      end
      graph = graph.to_h

      nodes = Array(graph['nodes'] || graph[:nodes])
      edges = Array(graph['edges'] || graph[:edges])
      node_by_id = nodes.index_by { |node| (node['id'] || node[:id]).to_s }
      prompt_ids = nodes.filter_map { |n| n['prompt_id'] || n[:prompt_id] }.uniq
      prompt_names = Prompt.where(id: prompt_ids).pluck(:id, :name).to_h

      node_label = lambda do |node|
        node_type = (node['node_type'] || node[:node_type]).to_s
        case node_type
        when 'input'
          cfg = node['config'] || node[:config] || {}
          key = cfg['param_key'] || cfg[:param_key]
          "Input node (param: #{key.presence || 'unset'})"
        when 'prompt'
          prompt_id = node['prompt_id'] || node[:prompt_id]
          prompt_name = prompt_names[prompt_id] || "prompt_id:#{prompt_id}"
          "Prompt node (#{prompt_name})"
        when 'output'
          'Output node'
        when 'start'
          'Start node'
        else
          "#{node_type.capitalize} node"
        end
      end

      flow_edges = edges.select do |edge|
        (edge['source_port'] || edge[:source_port]).to_s == 'flow' &&
          (edge['target_port'] || edge[:target_port]).to_s == 'flow'
      end
      var_edges = edges.reject { |edge| flow_edges.include?(edge) }

      flow_out = Hash.new { |h, k| h[k] = [] }
      flow_edges.each do |edge|
        source = (edge['source_node_id'] || edge[:source_node_id]).to_s
        target = (edge['target_node_id'] || edge[:target_node_id]).to_s
        flow_out[source] << target
      end

      start_ids = nodes
                  .select { |n| (n['node_type'] || n[:node_type]).to_s == 'start' }
                  .map { |n| (n['id'] || n[:id]).to_s }
      output_ids = nodes
                   .select { |n| (n['node_type'] || n[:node_type]).to_s == 'output' }
                   .map { |n| (n['id'] || n[:id]).to_s }

      if start_ids.empty?
        simulation_errors << { type: :missing_start_node, message: 'Flow must contain a start node.' }
      end
      if output_ids.empty?
        simulation_errors << { type: :missing_output_node, message: 'Flow must contain an output node.' }
      end

      reachable_flow = Set.new
      queue = start_ids.dup
      until queue.empty?
        current = queue.shift
        next if reachable_flow.include?(current)

        reachable_flow.add(current)
        flow_out[current].each { |target| queue << target }
      end

      path_to_output = output_ids.any? { |id| reachable_flow.include?(id) }
      unless simulation_errors.any? || path_to_output
        simulation_errors << {
          type: :missing_start_to_output_path,
          message: 'No flow path exists from Start node to Output node.'
        }
      end

      incoming_var = Hash.new { |h, k| h[k] = [] }
      outgoing_var = Hash.new { |h, k| h[k] = [] }
      var_edges.each do |edge|
        source = (edge['source_node_id'] || edge[:source_node_id]).to_s
        source_port = (edge['source_port'] || edge[:source_port]).to_s
        target = (edge['target_node_id'] || edge[:target_node_id]).to_s
        target_port = (edge['target_port'] || edge[:target_port]).to_s
        outgoing_var[[source, source_port]] << edge
        incoming_var[[target, target_port]] << edge
      end

      active_nodes = reachable_flow.dup
      visit_dependencies = lambda do |node_id|
        node = node_by_id[node_id]
        return if node.nil?

        input_ports = node['input_ports'] || node[:input_ports] || {}
        Array(input_ports.keys).map(&:to_s).reject { |port| port == 'flow' }.each do |port|
          (incoming_var[[node_id, port]] || []).each do |edge|
            source = (edge['source_node_id'] || edge[:source_node_id]).to_s
            next if active_nodes.include?(source)

            active_nodes.add(source)
            visit_dependencies.call(source)
          end
        end
      end
      reachable_flow.each { |id| visit_dependencies.call(id) }

      active_nodes.each do |node_id|
        node = node_by_id[node_id]
        next if node.nil?
        node_type = (node['node_type'] || node[:node_type]).to_s

        if node_type == 'input'
          cfg = node['config'] || node[:config] || {}
          key = cfg['param_key'] || cfg[:param_key]
          if key.blank?
            simulation_errors << { type: :missing_input_key, message: "#{node_label.call(node)} is missing param key." }
          end
        end

        input_ports = node['input_ports'] || node[:input_ports] || {}
        Array(input_ports.keys).map(&:to_s).reject { |port| port == 'flow' }.each do |port|
          connected = incoming_var[[node_id, port]].present?
          next if connected

          simulation_errors << {
            type: :missing_input_edge,
            message: "#{node_label.call(node)} is missing input for '#{port}'."
          }
        end

        output_ports = node['output_ports'] || node[:output_ports] || {}
        Array(output_ports.keys).map(&:to_s).reject { |port| port == 'flow' }.each do |port|
          edges_for_port = outgoing_var[[node_id, port]] || []
          connected_to_active = edges_for_port.any? do |edge|
            target = (edge['target_node_id'] || edge[:target_node_id]).to_s
            active_nodes.include?(target)
          end
          next if connected_to_active

          simulation_errors << {
            type: :unused_output_port,
            message: "#{node_label.call(node)} has an unused output '#{port}'."
          }
        end
      end

      nodes.each do |node|
        node_id = (node['id'] || node[:id]).to_s
        node_type = (node['node_type'] || node[:node_type]).to_s
        next if node_type == 'start'
        next if active_nodes.include?(node_id)

        simulation_errors << {
          type: :orphaned_node,
          message: "#{node_label.call(node)} is not used by the start-to-output flow."
        }
      end

      if simulation_errors.any?
        render json: { success: false, mode: mode, errors: simulation_errors }, status: :unprocessable_entity
      else
        render json: {
          success: true,
          mode: mode,
          result: {
            status: 'simulated',
            outputs: {},
            execution_log: [],
            checks: {
              nodes: nodes.size,
              edges: edges.size,
              active_nodes: active_nodes.size
            }
          }
        }
      end
      return
    end

    eval_graph = graph_payload.presence || flow.graph_json
    validation_errors = PromptFlowValidationService.new(flow, graph: eval_graph).call
    if validation_errors.any?
      render json: { success: false, mode: mode, errors: validation_errors }, status: :unprocessable_entity
      return
    end

    eval_session = "PROMPT_FLOW_EVAL_#{SecureRandom.uuid}"
    previous_ailog_session = Current.ailog_session
    Current.ailog_session = eval_session
    execution = nil
    begin
      execution = PromptFlowExecutionService.new(flow, graph: eval_graph).execute(inputs: inputs_payload)
    ensure
      Current.ailog_session = previous_ailog_session
    end

    eval_logs = AiLog.where(session_uuid: eval_session)
    input_tokens = eval_logs.sum(:input_tokens).to_i
    output_tokens = eval_logs.sum(:output_tokens).to_i
    total_cost = eval_logs.sum(:total_cost).to_f
    log_count = eval_logs.count

    if log_count.zero? && execution.present?
      metrics = Array(execution.execution_log).filter_map do |entry|
        pm = entry['prompt_metrics'] || entry[:prompt_metrics]
        pm if pm.is_a?(Hash)
      end
      log_count = metrics.filter_map { |m| m['ai_log_id'] || m[:ai_log_id] }.uniq.count
      input_tokens = metrics.sum { |m| (m['input_tokens'] || m[:input_tokens]).to_i }
      output_tokens = metrics.sum { |m| (m['output_tokens'] || m[:output_tokens]).to_i }
      total_cost = metrics.sum { |m| (m['total_cost'] || m[:total_cost]).to_f }
    end

    result = {
      status: execution.status,
      outputs: execution.outputs,
      execution_log: execution.execution_log,
      error_message: execution.error_message,
      ai_costs: {
        total_cost: total_cost.round(6),
        log_count: log_count,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        total_tokens: input_tokens + output_tokens
      }
    }

    render json: { success: true, mode: mode, result: result }
  rescue StandardError => e
    render json: { success: false, mode: mode, errors: [{ type: :execution_error, message: e.message }] }, status: :unprocessable_entity
  end

  action_item :activate, only: :show, if: proc { !resource.is_current? } do
    link_to 'Set Active', activate_admin_prompt_flow_path(resource),
            method: :patch,
            data: { confirm: 'Set this version as the active prompt flow?' }
  end

  index do
    selectable_column
    id_column
    column :name
    column :status do |flow|
      display_status = if flow.is_current?
                         'active'
                       elsif flow.status == 'invalid'
                         'invalid'
                       else
                         'draft'
                       end
      status_tag display_status
    end
    column :version_number
    column :max_executions
    column :updated_at
    actions
  end

  filter :name
  filter :status, as: :select, collection: %w[draft invalid]
  filter :is_current
  filter :updated_at

  canvas_styles = <<~CSS
    .pf-node {
      background: #0b0f1a;
      border: 1px solid #1f2937;
      border-radius: 8px;
      color: #e5e7eb;
      min-width: 180px;
      box-shadow: 0 6px 14px rgba(0, 0, 0, 0.35);
      font-size: 12px;
    }
    .pf-node__header {
      padding: 6px 10px;
      border-bottom: 1px solid #1f2937;
      font-weight: 600;
      text-transform: capitalize;
      display: flex;
      align-items: center;
      gap: 6px;
      justify-content: space-between;
    }
    .pf-node__delete {
      border: 0;
      background: transparent;
      color: #94a3b8;
      cursor: pointer;
      font-size: 14px;
      line-height: 1;
      padding: 0;
    }
    .pf-node__delete:hover {
      color: #f87171;
    }
    .pf-node__body {
      padding: 8px 10px;
      display: grid;
      gap: 6px;
    }
    .pf-node__inputs {
      display: grid;
      gap: 6px;
    }
    .pf-node__row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 6px;
      color: #cbd5f5;
    }
    .pf-node__row span:first-child {
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }
    .pf-node__row span:last-child {
      display: inline-flex;
      align-items: center;
      justify-content: flex-end;
      min-width: 24px;
    }
    .pf-node__pill {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      font-weight: 600;
      font-size: 11px;
      letter-spacing: 0.02em;
      color: #93c5fd;
    }
    .pf-node__input {
      width: 100%;
      background: #0f172a;
      color: #f9fafb;
      border: 1px solid #334155;
      border-radius: 4px;
      padding: 4px 6px;
      font-size: 12px;
    }
    .pf-node--start .pf-node__header { color: #93c5fd; }
    .pf-node--input .pf-node__header { color: #86efac; }
    .pf-node--output .pf-node__header { color: #fca5a5; }
    .pf-node--prompt .pf-node__header { color: #fcd34d; }
  CSS

  form do |f|
    flow = f.object
    graph = flow.graph_json.presence || {}
    if graph.is_a?(String)
      begin
        graph = JSON.parse(graph)
      rescue JSON::ParserError
        graph = {}
      end
    end
    graph_nodes = graph['nodes']
    graph_edges = graph['edges']
    if (graph_nodes.blank? || graph_edges.blank?) && flow.persisted?
      graph_nodes ||= flow.nodes.as_json(only: %i[id node_type prompt_id position_x position_y input_ports output_ports config])
      graph_edges ||= flow.edges.as_json(only: %i[id source_node_id target_node_id source_port target_port])
    end
    nodes_json = (graph_nodes || []).to_json
    edges_json = (graph_edges || []).to_json
    prompts_json = Prompt.order(:name).map { |p| { id: p.id, name: p.name, tags: p.tags_list } }.to_json

    f.inputs do
      if flow.persisted?
        li class: 'input stringish' do
          label 'Version', class: 'label'
          span flow.version_number.to_s
        end
      end
      f.input :name
      f.input :description, as: :string
      f.input :max_executions
      f.input :graph_json, as: :hidden
    end

    panel 'Flow Canvas' do
      div do
        style do
          raw canvas_styles
        end
      end

      div class: 'prompt-flow-palette', style: 'display:flex; gap:8px; margin-bottom:12px;' do
        button 'Add Input', type: 'button', id: 'prompt-flow-add-input', class: 'button'
        button 'Add Prompt', type: 'button', id: 'prompt-flow-add-prompt', class: 'button'
        button 'Test Flow',
               type: 'button',
               id: 'prompt-flow-test-simulate',
               class: 'button',
               title: (flow.persisted? ? nil : 'Save this draft first to run tests')
        button 'Evaluate',
               type: 'button',
               id: 'prompt-flow-evaluate-open',
               class: 'button',
               title: (flow.persisted? ? nil : 'Save this draft first to run evaluate')
      end

      div id: 'prompt-flow-canvas',
          data: {
            editable: true,
            flow_id: flow.persisted? ? flow.id : nil,
            nodes: nodes_json,
            edges: edges_json,
            prompts: prompts_json,
            test_execute_url: flow.persisted? ? test_execute_admin_prompt_flow_path(flow) : nil
          },
          style: 'height: 600px; border: 1px solid #e5e7eb; position: relative;' do
        span 'Canvas will render here once jsPlumb is initialized.', class: 'text-gray-500'
      end

      div id: 'prompt-flow-test-modal',
          style: 'display:none; position:fixed; inset:0; background:rgba(0,0,0,0.65); z-index:9999; align-items:center; justify-content:center;' do
        div style: 'background:#0b0f1a; border:1px solid #1f2937; border-radius:8px; width:min(760px,92vw); max-height:88vh; overflow:auto; padding:16px;' do
          h3 'Evaluate Flow', style: 'margin:0 0 12px 0; color:#e5e7eb; font-size:16px;'
          div id: 'prompt-flow-test-inputs', style: 'display:grid; gap:8px; margin-bottom:12px;'
          div style: 'display:flex; gap:8px; margin-bottom:12px;' do
            button 'Run Evaluate', type: 'button', id: 'prompt-flow-test-run', class: 'button'
            button 'Close', type: 'button', id: 'prompt-flow-test-close', class: 'button'
          end
          div id: 'prompt-flow-test-result', style: 'background:#111827; border:1px solid #374151; border-radius:6px; padding:10px; color:#e5e7eb; white-space:pre-wrap;'
            text_node 'Run a test to view status, outputs, and timeline.'
        end
      end

      script type: 'text/javascript' do
        raw <<~JS
          (function() {
            var canvas = document.getElementById('prompt-flow-canvas');
            if (!canvas) { return; }

            function loadJsPlumb(callback) {
              if (window.jsPlumb) { callback(); return; }

              var script = document.createElement('script');
              script.src = 'https://unpkg.com/@jsplumb/browser-ui@6.2.10/js/jsplumb.browser-ui.umd.js';
              script.onload = callback;
              document.head.appendChild(script);
            }

            function initCanvas() {
              if (!window.jsPlumb || typeof window.jsPlumb.newInstance !== 'function') { return; }

              var tk = window.jsPlumb;
              var instance = tk.newInstance({
                dragOptions: {
                  cursor: 'pointer',
                  zIndex: 2000,
                  grid: [20, 20],
                  containment: 'notNegative'
                },
                connectionOverlays: [
                  {
                    type: 'Arrow',
                    options: { location: 1, width: 10, length: 10, id: 'ARROW' }
                  }
                ],
                container: canvas
              });

              var placeholder = canvas.querySelector('span');
              if (placeholder) { placeholder.remove(); }

              var editable = canvas.dataset.editable === 'true';
              function parseDatasetJson(value, fallback) {
                if (!value) { return fallback; }
                if (typeof value === 'string') {
                  try {
                    return JSON.parse(value);
                  } catch (error) {
                    console.error('[PromptFlow] Failed to parse dataset JSON', value, error);
                    return fallback;
                  }
                }
                return value;
              }

              function ensureArray(value) {
                if (Array.isArray(value)) { return value; }
                if (value && Array.isArray(value.nodes)) { return value.nodes; }
                return [];
              }

              var nodes = ensureArray(parseDatasetJson(canvas.dataset.nodes, []));
              var edges = ensureArray(parseDatasetJson(canvas.dataset.edges, []));
              var promptsRaw = parseDatasetJson(canvas.dataset.prompts, []);
              var prompts = Array.isArray(promptsRaw) ? promptsRaw : [];
              var testExecuteUrl = canvas.dataset.testExecuteUrl || canvas.dataset.test_execute_url;
              var flowId = canvas.dataset.flowId || canvas.dataset.flow_id;
              var csrfToken = document.querySelector('meta[name=\"csrf-token\"]')?.getAttribute('content');
              if (!nodes.length) {
                console.warn('[PromptFlow][show] No nodes parsed for read-only canvas', canvas.dataset.nodes);
              }

              if (!nodes.some(function(n) { return n.node_type === 'start'; })) {
                nodes.push({
                  id: 'start',
                  node_type: 'start',
                  position_x: 40,
                  position_y: 40,
                  input_ports: {},
                  output_ports: { flow: {} }
                });
              }

              if (!nodes.some(function(n) { return n.node_type === 'output'; })) {
                nodes.push({
                  id: 'output',
                  node_type: 'output',
                  position_x: 380,
                  position_y: 40,
                  input_ports: { response: {} },
                  output_ports: {}
                });
              }


              function nodeId(node) { return 'prompt-flow-node-' + node.id; }
              function canDeleteNode(node) {
                return !['start', 'output'].includes(node.node_type);
              }

              function createNodeElement(node) {
                var el = document.createElement('div');
                el.id = nodeId(node);
                el.className = 'prompt-flow-node pf-node pf-node--' + node.node_type;
                el.dataset.nodeId = node.id;
                el.style.position = 'absolute';
                el.style.left = (node.position_x || 40) + 'px';
                el.style.top = (node.position_y || 40) + 'px';
                var promptList = (typeof prompts !== 'undefined' && Array.isArray(prompts)) ? prompts : [];
                var deleteButtonHtml = canDeleteNode(node)
                  ? '<button type=\"button\" class=\"pf-node__delete\" data-node-id=\"' + node.id + '\" title=\"Delete node\">x</button>'
                  : '';
                var titleHtml = '<div class=\"pf-node__header\"><span>' + node.node_type + '</span>' + deleteButtonHtml + '</div>';
                var bodyHtml = (node.node_type === 'start') ? '' : '<div class=\"pf-node__body\">';

                if (node.node_type === 'input') {
                  var value = (node.config && node.config.param_key) ? node.config.param_key : '';
                  bodyHtml += '<div><input class=\"prompt-flow-node__param pf-node__input\" data-node-id=\"' + node.id + '\" placeholder=\"param key\" value=\"' + value + '\" /></div>';
                }

                if (node.node_type === 'prompt') {
                  var options = promptList.map(function(p) {
                    var selected = node.prompt_id === p.id ? 'selected' : '';
                    return '<option value=\"' + p.id + '\" ' + selected + '>' + p.name + '</option>';
                  }).join('');
                  bodyHtml += '<div><select class=\"prompt-flow-node__prompt pf-node__input\" data-node-id=\"' + node.id + '\">' + options + '</select></div>';
                  bodyHtml += '<div class=\"pf-node__row\"><span>Response</span><span></span></div>';
                  bodyHtml += '<div class=\"pf-node__inputs\">';
                  Object.keys(node.input_ports || {}).forEach(function(port) {
                    bodyHtml += '<div class=\"pf-node__row\"><span>' + port + '</span><span></span></div>';
                  });
                  bodyHtml += '</div>';
                }

                if (node.node_type === 'output') {
                  bodyHtml += '<div class=\"pf-node__row\"><span>Response</span><span></span></div>';
                }

                bodyHtml += '</div>';
                el.innerHTML = titleHtml + bodyHtml;
                canvas.appendChild(el);
                return el;
              }

              function removeNode(node, el) {
                if (!canDeleteNode(node)) { return; }
                if (!window.confirm('Delete this node and all connected edges?')) { return; }

                if (typeof instance.deleteConnectionsForElement === 'function') {
                  instance.deleteConnectionsForElement(el);
                }
                if (typeof instance.removeAllEndpoints === 'function') {
                  instance.removeAllEndpoints(el, true);
                }
                if (typeof instance.unmanage === 'function') {
                  instance.unmanage(el, true);
                }
                if (typeof instance.remove === 'function') {
                  instance.remove(el);
                } else {
                  el.remove();
                }

                nodes = nodes.filter(function(n) { return n.id != node.id; });
                // Defensive cleanup for any orphaned endpoint SVGs left by the renderer.
                canvas.querySelectorAll('.jtk-endpoint').forEach(function(endpointEl) {
                  var ownerId = endpointEl.getAttribute('data-jtk-managed');
                  if (ownerId && !document.getElementById(ownerId)) {
                    endpointEl.remove();
                  }
                });
                instance.repaintEverything();
              }

              function bindNodeControls(node, el) {
                var deleteBtn = el.querySelector('.pf-node__delete');
                if (deleteBtn) {
                  deleteBtn.addEventListener('click', function() {
                    removeNode(node, el);
                  });
                }
              }

              var flowOutEndpoint = {
                endpoint: tk.DotEndpoint.type,
                paintStyle: { stroke: '#ffffff', fill: '#ffffff', radius: 8, strokeWidth: 2 },
                source: true,
                maxConnections: 1,
                connector: {
                  type: 'Flowchart',
                  options: { stub: [40, 60], gap: 10, cornerRadius: 5, alwaysRespectStubs: true }
                }
              };

              var flowInEndpoint = {
                endpoint: tk.DotEndpoint.type,
                paintStyle: { stroke: '#ffffff', fill: 'transparent', radius: 8, strokeWidth: 2 },
                target: true,
                maxConnections: -1
              };

              var varOutEndpoint = {
                endpoint: tk.DotEndpoint.type,
                paintStyle: { stroke: '#16a34a', fill: '#16a34a', radius: 6, strokeWidth: 1 },
                source: true,
                maxConnections: -1
              };

              var varInEndpoint = {
                endpoint: tk.DotEndpoint.type,
                paintStyle: { stroke: '#16a34a', fill: '#16a34a', radius: 6, strokeWidth: 1 },
                target: true,
                maxConnections: 1
              };

              function addPorts(node, el) {
                var inputPorts = Object.keys(node.input_ports || {});
                var outputPorts = Object.keys(node.output_ports || {});
                var rowHeight = 26;
                var flowBaseOffset = 15;
                var varBaseOffsetDefault = flowBaseOffset + 35;
                var varBaseOffsetInput = flowBaseOffset + 40;
                var varBaseOffsetPrompt = flowBaseOffset + 71;

                function leftAnchorAt(row, baseOffset) {
                  return [0, 0, -1, 0, 0, baseOffset + row * rowHeight];
                }

                function rightAnchorAt(row, baseOffset) {
                  return [1, 0, 1, 0, 0, baseOffset + row * rowHeight];
                }

                if (node.node_type === 'start') {
                  instance.addEndpoint(el, flowOutEndpoint, {
                    anchor: rightAnchorAt(0, flowBaseOffset),
                    uuid: node.id + '-flow-out',
                    parameters: { portType: 'flow_out', portKey: 'flow' }
                  });
                  return;
                }

                if (node.node_type === 'output') {
                  instance.addEndpoint(el, flowInEndpoint, {
                    anchor: leftAnchorAt(0, flowBaseOffset),
                    uuid: node.id + '-flow-in',
                    parameters: { portType: 'flow_in', portKey: 'flow' }
                  });
                  instance.addEndpoint(el, varInEndpoint, {
                    anchor: leftAnchorAt(0, varBaseOffsetDefault),
                    uuid: node.id + '-in-response',
                    parameters: { portType: 'var_in', portKey: 'response' }
                  });
                  return;
                }

                if (node.node_type === 'input') {                
                  outputPorts.forEach(function(port) {
                    instance.addEndpoint(el, varOutEndpoint, {
                      anchor: rightAnchorAt(0, varBaseOffsetInput),
                      uuid: node.id + '-out-' + port,
                      parameters: { portType: 'var_out', portKey: port }
                    });
                  });
                  return;
                }

                if (node.node_type === 'prompt') {
                  instance.addEndpoint(el, flowInEndpoint, {
                    anchor: leftAnchorAt(0, flowBaseOffset),
                    uuid: node.id + '-flow-in',
                    parameters: { portType: 'flow_in', portKey: 'flow' }
                  });
                  instance.addEndpoint(el, flowOutEndpoint, {
                    anchor: rightAnchorAt(0, flowBaseOffset),
                    uuid: node.id + '-flow-out',
                    parameters: { portType: 'flow_out', portKey: 'flow' }
                  });

                  instance.addEndpoint(el, varOutEndpoint, {
                    anchor: rightAnchorAt(0, varBaseOffsetPrompt),
                    uuid: node.id + '-out-response',
                    parameters: { portType: 'var_out', portKey: 'response' }
                  });

                  inputPorts.forEach(function(port, index) {
                    instance.addEndpoint(el, varInEndpoint, {
                      anchor: leftAnchorAt(index + 1, varBaseOffsetPrompt),
                      uuid: node.id + '-in-' + port,
                      parameters: { portType: 'var_in', portKey: port }
                    });
                  });
                }
              }

              instance.bind('beforeDrop', function(info) {
                if (!editable) { return false; }

                var sourcePort = info.sourceEndpoint.getParameter('portType');
                var targetPort = info.targetEndpoint.getParameter('portType');
                if (!sourcePort || !targetPort) { return false; }
                var validFlow = sourcePort === 'flow_out' && targetPort === 'flow_in';
                var validVar = sourcePort === 'var_out' && targetPort === 'var_in';
                if (!validFlow && !validVar) { return false; }
                if (info.sourceId === info.targetId) { return false; }

                var sourceKey = info.sourceEndpoint.getParameter('portKey');
                var targetKey = info.targetEndpoint.getParameter('portKey');
                var duplicate = instance.getAllConnections().some(function(conn) {
                  return conn.sourceId === info.sourceId &&
                    conn.targetId === info.targetId &&
                    conn.endpoints[0].getParameter('portKey') === sourceKey &&
                    conn.endpoints[1].getParameter('portKey') === targetKey;
                });

                return !duplicate;
              });

              function updatePromptPorts(node, el, promptId, promptName) {
                var prompt = prompts.find(function(p) { return p.id == promptId; });
                if (!prompt && promptName) {
                  prompt = prompts.find(function(p) { return p.name === promptName; });
                }
                var tags = prompt && prompt.tags ? prompt.tags : [];

                var preserved = getAllConnections().map(function(conn) {
                  var sourceNodeId = conn.source && conn.source.dataset ? conn.source.dataset.nodeId : null;
                  var targetNodeId = conn.target && conn.target.dataset ? conn.target.dataset.nodeId : null;
                  if (sourceNodeId != node.id && targetNodeId != node.id) { return null; }

                  function endpointParam(endpoint, key) {
                    if (!endpoint) { return null; }
                    if (typeof endpoint.getParameter === 'function') { return endpoint.getParameter(key); }
                    if (typeof endpoint.getParameters === 'function') { return (endpoint.getParameters() || {})[key]; }
                    if (endpoint.parameters) { return endpoint.parameters[key]; }
                    return null;
                  }

                  var sourceType = endpointParam(conn.endpoints && conn.endpoints[0], 'portType');
                  var sourceKey = endpointParam(conn.endpoints && conn.endpoints[0], 'portKey');
                  var targetType = endpointParam(conn.endpoints && conn.endpoints[1], 'portType');
                  var targetKey = endpointParam(conn.endpoints && conn.endpoints[1], 'portKey');

                  var keep = (sourceNodeId == node.id && (sourceType === 'flow_out' || (sourceType === 'var_out' && sourceKey === 'response'))) ||
                    (targetNodeId == node.id && targetType === 'flow_in');
                  if (!keep) { return null; }

                  return {
                    sourceNodeId: sourceNodeId,
                    targetNodeId: targetNodeId,
                    sourceType: sourceType,
                    sourceKey: sourceKey,
                    targetType: targetType,
                    targetKey: targetKey
                  };
                }).filter(function(item) { return item; });

                node.prompt_id = promptId;
                node.input_ports = tags.reduce(function(acc, tag) {
                  acc[tag] = {};
                  return acc;
                }, {});
                node.output_ports = { response: {} };

                instance.removeAllEndpoints(el);
                addPorts(node, el);

                var inputsEl = el.querySelector('.pf-node__inputs');
                if (!inputsEl) {
                  inputsEl = document.createElement('div');
                  inputsEl.className = 'pf-node__inputs';
                  el.querySelector('.pf-node__body')?.appendChild(inputsEl);
                }

                inputsEl.innerHTML = '';
                Object.keys(node.input_ports || {}).forEach(function(port) {
                  var row = document.createElement('div');
                  row.className = 'pf-node__row';
                  row.innerHTML = '<span>' + port + '</span><span></span>';
                  inputsEl.appendChild(row);
                });

                preserved.forEach(function(conn) {
                  var sourceUuid = conn.sourceType === 'flow_out'
                    ? conn.sourceNodeId + '-flow-out'
                    : conn.sourceNodeId + '-out-' + conn.sourceKey;
                  var targetUuid = conn.targetType === 'flow_in'
                    ? conn.targetNodeId + '-flow-in'
                    : conn.targetNodeId + '-in-' + conn.targetKey;
                  instance.connect({ uuids: [sourceUuid, targetUuid] });
                });
                instance.repaintEverything();
              }

              function getAllConnections() {
                if (typeof instance.getAllConnections === 'function') {
                  return instance.getAllConnections();
                }
                if (typeof instance.getConnections === 'function') {
                  return instance.getConnections();
                }
                if (typeof instance.select === 'function') {
                  return instance.select().get();
                }
                return [];
              }

              function updateInputParam(node, el, value) {
                var oldKey = node.config && node.config.param_key ? node.config.param_key : null;
                var existingConnections = getAllConnections().filter(function(conn) {
                  if (!conn.source || !conn.source.dataset) { return false; }
                  if (conn.source.dataset.nodeId != node.id) { return false; }
                  return true;
                }).map(function(conn) {
                  var endpoint = conn.endpoints && conn.endpoints[1];
                  var targetPort = null;
                  if (endpoint) {
                    if (typeof endpoint.getParameter === 'function') {
                      targetPort = endpoint.getParameter('portKey');
                    } else if (typeof endpoint.getParameters === 'function') {
                      targetPort = (endpoint.getParameters() || {}).portKey;
                    } else if (endpoint.parameters) {
                      targetPort = endpoint.parameters.portKey;
                    }
                  }
                  return {
                    targetNodeId: conn.target && conn.target.dataset ? conn.target.dataset.nodeId : null,
                    targetPort: targetPort
                  };
                }).filter(function(item) {
                  return item.targetNodeId && item.targetPort;
                });

                node.config = node.config || {};
                node.config.param_key = value;
                node.output_ports = {};
                if (value) { node.output_ports[value] = {}; }

                instance.removeAllEndpoints(el);
                addPorts(node, el);

                existingConnections.forEach(function(conn) {
                  if (!value) { return; }
                  var sourceUuid = node.id + '-out-' + value;
                  var targetUuid = conn.targetPort === 'flow'
                    ? conn.targetNodeId + '-flow-in'
                    : conn.targetNodeId + '-in-' + conn.targetPort;
                  instance.connect({ uuids: [sourceUuid, targetUuid] });
                });
                instance.repaintEverything();
              }

              instance.batch(function() {
                nodes.forEach(function(node) {
                  var el = createNodeElement(node);
                  addPorts(node, el);
                  if (editable) { instance.manage(el); }
                  bindNodeControls(node, el);
                  if (node.node_type === 'prompt') {
                    var select = el.querySelector('.prompt-flow-node__prompt');
                    if (select) {
                      select.addEventListener('change', function(event) {
                        var value = parseInt(event.target.value, 10);
                        var name = event.target.options[event.target.selectedIndex]?.text || null;
                        updatePromptPorts(node, el, value, name);
                      });
                    }
                  }
                  if (node.node_type === 'input') {
                    var input = el.querySelector('.prompt-flow-node__param');
                    if (input) {
                      input.addEventListener('change', function(event) {
                        updateInputParam(node, el, event.target.value.trim());
                      });
                    }
                  }
                });

                edges.forEach(function(edge) {
                  var sourceUuid = edge.source_port === 'flow'
                    ? edge.source_node_id + '-flow-out'
                    : edge.source_node_id + '-out-' + edge.source_port;
                  var targetUuid = edge.target_port === 'flow'
                    ? edge.target_node_id + '-flow-in'
                    : edge.target_node_id + '-in-' + edge.target_port;
                  var connection = instance.connect({ uuids: [sourceUuid, targetUuid] });
                  if (connection && edge.id) {
                    connection.edgeId = edge.id;
                  }
                });
              });

              // Removed fallback node injection; only render actual nodes.

              function syncNodeFromDom(node) {
                var el = document.getElementById(nodeId(node));
                if (!el) { return null; }
                node.position_x = el.offsetLeft;
                node.position_y = el.offsetTop;

                if (node.node_type === 'input') {
                  var input = el.querySelector('.prompt-flow-node__param');
                  var value = input ? input.value.trim() : '';
                  node.config = node.config || {};
                  node.config.param_key = value;
                  node.output_ports = {};
                  if (value) { node.output_ports[value] = {}; }
                } else if (node.node_type === 'prompt') {
                  var select = el.querySelector('.prompt-flow-node__prompt');
                  var value = select ? parseInt(select.value, 10) : node.prompt_id;
                  var name = select ? select.options[select.selectedIndex]?.text || null : null;
                  var prompt = prompts.find(function(p) { return p.id == value; });
                  if (!prompt && name) {
                    prompt = prompts.find(function(p) { return p.name === name; });
                  }
                  var tags = prompt && prompt.tags ? prompt.tags : [];
                  node.prompt_id = value;
                  node.input_ports = tags.reduce(function(acc, tag) {
                    acc[tag] = {};
                    return acc;
                  }, {});
                  node.output_ports = { response: {} };
                } else if (node.node_type === 'output') {
                  node.input_ports = { response: {} };
                  node.output_ports = {};
                } else if (node.node_type === 'start') {
                  node.input_ports = {};
                  node.output_ports = { flow: {} };
                }

                return node;
              }

              function serializeGraph() {
                var graphNodes = nodes.map(function(node) {
                  return syncNodeFromDom(node);
                }).filter(function(node) { return node; });

                function endpointPortKey(endpoint) {
                  if (!endpoint) { return null; }
                  if (typeof endpoint.getParameter === 'function') {
                    return endpoint.getParameter('portKey');
                  }
                  if (typeof endpoint.getParameters === 'function') {
                    var params = endpoint.getParameters() || {};
                    return params.portKey || null;
                  }
                  if (endpoint.parameters && endpoint.parameters.portKey) {
                    return endpoint.parameters.portKey;
                  }
                  return null;
                }

                var graphEdges = getAllConnections().map(function(conn) {
                  var sourcePort = endpointPortKey(conn.endpoints && conn.endpoints[0]);
                  var targetPort = endpointPortKey(conn.endpoints && conn.endpoints[1]);
                  return {
                    source_node_id: conn.source.dataset.nodeId,
                    target_node_id: conn.target.dataset.nodeId,
                    source_port: sourcePort,
                    target_port: targetPort
                  };
                });

                return {
                  nodes: graphNodes,
                  edges: graphEdges,
                  meta: {
                    canvas: {
                      width: canvas.offsetWidth,
                      height: canvas.offsetHeight
                    }
                  }
                };
              }

              function createNodeFromPalette(type) {
                var node = {
                  id: 'temp-' + Date.now(),
                  node_type: type,
                  position_x: 80,
                  position_y: 120,
                  input_ports: {},
                  output_ports: {},
                  config: {}
                };

                if (type === 'input') {
                  node.output_ports = { param: {} };
                  node.config.param_key = 'param';
                } else if (type === 'output') {
                  node.input_ports = { in: {} };
                } else if (type === 'prompt') {
                  var firstPrompt = prompts[0];
                  node.prompt_id = firstPrompt ? firstPrompt.id : null;
                  var tags = firstPrompt ? firstPrompt.tags : [];
                  node.input_ports = tags.reduce(function(acc, tag) {
                    acc[tag] = {};
                    return acc;
                  }, {});
                  node.output_ports = { response: {} };
                }

                if (!nodes.some(function(n) { return n.id == node.id; })) {
                  nodes.push(node);
                }

                var el = createNodeElement(node);
                addPorts(node, el);
                instance.manage(el);
                bindNodeControls(node, el);
                if (node.node_type === 'prompt') {
                  var select = el.querySelector('.prompt-flow-node__prompt');
                  if (select) {
                    select.addEventListener('change', function(event) {
                      var value = parseInt(event.target.value, 10);
                      var name = event.target.options[event.target.selectedIndex]?.text || null;
                      updatePromptPorts(node, el, value, name);
                    });
                  }
                }
                if (node.node_type === 'input') {
                  var input = el.querySelector('.prompt-flow-node__param');
                  if (input) {
                    input.addEventListener('change', function(event) {
                      updateInputParam(node, el, event.target.value.trim());
                    });
                  }
                }
              }

              var addInputBtn = document.getElementById('prompt-flow-add-input');
              var addPromptBtn = document.getElementById('prompt-flow-add-prompt');
              if (addInputBtn) { addInputBtn.addEventListener('click', function() { createNodeFromPalette('input'); }); }
              if (addPromptBtn) { addPromptBtn.addEventListener('click', function() { createNodeFromPalette('prompt'); }); }

              var testModal = document.getElementById('prompt-flow-test-modal');
              var testSimulateBtn = document.getElementById('prompt-flow-test-simulate');
              var testEvaluateOpenBtn = document.getElementById('prompt-flow-evaluate-open');
              var testCloseBtn = document.getElementById('prompt-flow-test-close');
              var testRunBtn = document.getElementById('prompt-flow-test-run');
              var testInputsEl = document.getElementById('prompt-flow-test-inputs');
              var testResultEl = document.getElementById('prompt-flow-test-result');

              function inputKeysFromNodes() {
                return nodes
                  .filter(function(node) { return node.node_type === 'input'; })
                  .map(function(node) {
                    if (node.config && node.config.param_key) { return node.config.param_key; }
                    var ports = Object.keys(node.output_ports || {});
                    return ports[0] || null;
                  })
                  .filter(function(key) { return !!key; });
              }

              function renderTestInputs() {
                if (!testInputsEl) { return; }
                testInputsEl.innerHTML = '';
                var keys = inputKeysFromNodes();
                if (!keys.length) {
                  testInputsEl.innerHTML = '<div style=\"color:#9ca3af;\">No input nodes found.</div>';
                  return;
                }
                keys.forEach(function(key) {
                  var row = document.createElement('div');
                  row.style.display = 'grid';
                  row.style.gap = '4px';
                  row.innerHTML = '<label style=\"color:#cbd5e1; font-size:12px;\">' + key + '</label><input type=\"text\" data-test-input-key=\"' + key + '\" class=\"pf-node__input\" />';
                  testInputsEl.appendChild(row);
                });
              }

              function setInputsVisibility(visible) {
                if (!testInputsEl) { return; }
                testInputsEl.style.display = visible ? 'grid' : 'none';
              }

              function openTestModal(mode) {
                if (!testModal) { return; }
                setInputsVisibility(mode === 'evaluate');
                if (testRunBtn) {
                  testRunBtn.style.display = (mode === 'evaluate') ? '' : 'none';
                }
                testModal.style.display = 'flex';
              }

              function resolvedTestExecuteUrl() {
                if (testExecuteUrl) { return testExecuteUrl; }
                if (flowId) { return '/admin/prompt_flows/' + flowId + '/test_execute'; }
                return null;
              }

              function collectTestInputs() {
                var payload = {};
                if (!testInputsEl) { return payload; }
                testInputsEl.querySelectorAll('[data-test-input-key]').forEach(function(input) {
                  payload[input.getAttribute('data-test-input-key')] = input.value;
                });
                return payload;
              }

              function renderTestResult(data) {
                if (!testResultEl) { return; }
                if (!data) {
                  testResultEl.textContent = 'No result returned.';
                  return;
                }
                if (data.success === false) {
                  var errors = data.errors || [];
                  if (!errors.length) {
                    testResultEl.textContent = 'Validation failed.';
                    return;
                  }
                  var lines = ['Validation failed:'];
                  errors.forEach(function(error) {
                    lines.push('- ' + (error.message || 'Unknown error'));
                  });
                  testResultEl.textContent = lines.join('\\n');
                  return;
                }
                var result = data.result || {};
                var executionLog = result.execution_log || [];
                var totalExecutionMs = null;
                if (executionLog.length) {
                  var started = executionLog
                    .map(function(entry) { return Date.parse(entry.started_at); })
                    .filter(function(ts) { return !isNaN(ts); });
                  var ended = executionLog
                    .map(function(entry) { return Date.parse(entry.ended_at); })
                    .filter(function(ts) { return !isNaN(ts); });
                  if (started.length && ended.length) {
                    totalExecutionMs = Math.max.apply(null, ended) - Math.min.apply(null, started);
                  }
                }
                var lines = [];
                lines.push('Mode: ' + (data.mode || 'evaluate'));
                lines.push('Status: ' + (result.status || 'unknown'));
                if (totalExecutionMs !== null) {
                  lines.push('Total Execution Time: ' + (totalExecutionMs / 1000).toFixed(2) + 's');
                }
                if (result.error_message) { lines.push('Error: ' + result.error_message); }
                if (result.checks) {
                  lines.push('Checks: ' + JSON.stringify(result.checks));
                }
                if (result.ai_costs) {
                  lines.push('AI Cost Total: $' + (result.ai_costs.total_cost || 0));
                  lines.push('AI Logs: ' + (result.ai_costs.log_count || 0));
                  lines.push('AI Tokens: ' + (result.ai_costs.total_tokens || 0) + ' (' + (result.ai_costs.input_tokens || 0) + ' in / ' + (result.ai_costs.output_tokens || 0) + ' out)');
                }
                lines.push('');
                lines.push('Outputs:');
                lines.push(JSON.stringify(result.outputs || {}, null, 2));
                lines.push('');
                lines.push('Timeline:');
                lines.push(JSON.stringify(executionLog, null, 2));
                testResultEl.textContent = lines.join('\\n');
              }

              if (testEvaluateOpenBtn && testModal) {
                testEvaluateOpenBtn.addEventListener('click', function() {
                  openTestModal('evaluate');
                  renderTestInputs();
                  testResultEl.textContent = 'Run evaluate to view status, outputs, and timeline.';
                });
              }

              if (testCloseBtn && testModal) {
                testCloseBtn.addEventListener('click', function() {
                  setInputsVisibility(false);
                  if (testRunBtn) { testRunBtn.style.display = ''; }
                  testModal.style.display = 'none';
                });
              }

              if (testRunBtn) {
                testRunBtn.addEventListener('click', function() {
                  var executeUrl = resolvedTestExecuteUrl();
                  if (!executeUrl) {
                    renderTestResult({ success: false, errors: [{ message: 'Save this draft first to run evaluate.' }] });
                    return;
                  }
                  if (testResultEl) {
                    testResultEl.textContent = 'Running evaluation...';
                  }
                  testRunBtn.setAttribute('disabled', 'disabled');
                  fetch(executeUrl, {
                    method: 'POST',
                    headers: {
                      'Content-Type': 'application/json',
                      'X-CSRF-Token': csrfToken
                    },
                    body: JSON.stringify({
                      mode: 'evaluate',
                      inputs: collectTestInputs(),
                      graph: serializeGraph()
                    })
                  })
                    .then(function(resp) { return resp.json(); })
                    .then(function(data) { renderTestResult(data); })
                    .catch(function(error) {
                      renderTestResult({ success: false, errors: [{ message: error.message }] });
                    })
                    .finally(function() {
                      testRunBtn.removeAttribute('disabled');
                    });
                });
              }

              if (testSimulateBtn) {
                testSimulateBtn.addEventListener('click', function() {
                  openTestModal('simulate');
                  if (testResultEl) {
                    testResultEl.textContent = 'Running simulation...';
                  }
                  var executeUrl = resolvedTestExecuteUrl();
                  if (!executeUrl) {
                    if (testResultEl) {
                      renderTestResult({ success: false, mode: 'simulate', errors: [{ message: 'Save this draft first to run tests.' }] });
                    }
                    return;
                  }

                  testSimulateBtn.setAttribute('disabled', 'disabled');
                  fetch(executeUrl, {
                    method: 'POST',
                    headers: {
                      'Content-Type': 'application/json',
                      'X-CSRF-Token': csrfToken
                    },
                    body: JSON.stringify({
                      mode: 'simulate',
                      graph: serializeGraph()
                    })
                  })
                    .then(function(resp) { return resp.json(); })
                    .then(function(data) {
                      renderTestResult(data);
                    })
                    .catch(function(error) {
                      renderTestResult({ success: false, mode: 'simulate', errors: [{ message: error.message }] });
                    })
                    .finally(function() {
                      testSimulateBtn.removeAttribute('disabled');
                    });
                });
              }

              var form = canvas.closest('form');
              if (form) {
                form.addEventListener('submit', function(event) {
                  try {
                    var graphInput = form.querySelector('#prompt_flow_graph_json');
                    if (!graphInput) { return; }
                    var graphPayload = serializeGraph();
                    graphInput.value = JSON.stringify(graphPayload);
                  } catch (error) {
                    console.error('[PromptFlow] Failed to serialize graph', error);
                    event.preventDefault();
                    alert('Unable to save the flow due to a canvas error. Please reload and try again.');
                  }
                });
              }

              canvas.addEventListener('change', function(event) {
                var select = event.target.closest('.prompt-flow-node__prompt');
                if (!select) { return; }
                var nodeIdValue = select.getAttribute('data-node-id');
                var node = nodes.find(function(n) { return n.id == nodeIdValue; });
                if (!node) { return; }
                var value = parseInt(select.value, 10);
                var name = select.options[select.selectedIndex]?.text || null;
                updatePromptPorts(node, select.closest('.prompt-flow-node'), value, name);
              });
            }

            loadJsPlumb(function() {
              window.jsPlumb.ready(initCanvas);
            });
          })();
        JS
      end
    end

    f.actions
  end

  show do
    graph = resource.graph_json.presence || {}
    if graph.is_a?(String)
      begin
        graph = JSON.parse(graph)
      rescue JSON::ParserError
        graph = {}
      end
    end
    nodes_data = graph['nodes'] || resource.nodes.as_json(only: %i[id node_type prompt_id position_x position_y input_ports output_ports config])
    edges_data = graph['edges'] || resource.edges.as_json(only: %i[id source_node_id target_node_id source_port target_port])
    prompts_json = Prompt.order(:name).map { |p| { id: p.id, name: p.name, tags: p.tags_list } }.to_json
    nodes_json = nodes_data.to_json
    edges_json = edges_data.to_json

    attributes_table do
      row :id
      row :name
      row :description
      row :status do |flow|
        display_status = if flow.is_current?
                           'active'
                         elsif flow.status == 'invalid'
                           'invalid'
                         else
                           'draft'
                         end
        status_tag display_status
      end
      row :version_number
      row :max_executions
      row :created_by
      row :updated_by
      row :created_at
      row :updated_at
    end

    panel 'Flow Canvas (Read-Only)' do
      div do
        style do
          raw canvas_styles
        end
      end
      div id: 'prompt-flow-canvas',
          data: {
            editable: false,
            flow_id: resource.id,
            nodes: nodes_json,
            edges: edges_json,
            prompts: prompts_json
          },
          style: 'height: 600px; border: 1px solid #e5e7eb; position: relative;' do
        span 'Canvas will render here once jsPlumb is initialized.', class: 'text-gray-500'
      end

      script type: 'text/javascript' do
        raw <<~JS
          (function() {
            var canvas = document.getElementById('prompt-flow-canvas');
            if (!canvas) { return; }

            function loadJsPlumb(callback) {
              if (window.jsPlumb) { callback(); return; }

              var script = document.createElement('script');
              script.src = 'https://unpkg.com/@jsplumb/browser-ui@6.2.10/js/jsplumb.browser-ui.umd.js';
              script.onload = callback;
              document.head.appendChild(script);
            }

            function initCanvas() {
              if (!window.jsPlumb || typeof window.jsPlumb.newInstance !== 'function') { return; }

              var tk = window.jsPlumb;
              var instance = tk.newInstance({
                dragOptions: {
                  cursor: 'pointer',
                  zIndex: 2000,
                  grid: [20, 20],
                  containment: 'notNegative'
                },
                connectionOverlays: [
                  {
                    type: 'Arrow',
                    options: { location: 1, width: 10, length: 10, id: 'ARROW' }
                  }
                ],
                container: canvas
              });

              var placeholder = canvas.querySelector('span');
              if (placeholder) { placeholder.remove(); }
              var editable = canvas.dataset.editable === 'true';

              function parseDatasetJson(value, fallback) {
                if (!value) { return fallback; }
                if (typeof value === 'string') {
                  try {
                    return JSON.parse(value);
                  } catch (error) {
                    console.error('[PromptFlow] Failed to parse dataset JSON', value, error);
                    return fallback;
                  }
                }
                return value;
              }

              function ensureArray(value) {
                if (Array.isArray(value)) { return value; }
                if (value && Array.isArray(value.nodes)) { return value.nodes; }
                return [];
              }

              var nodes = ensureArray(parseDatasetJson(canvas.dataset.nodes, []));
              var edges = ensureArray(parseDatasetJson(canvas.dataset.edges, []));
              var promptsRaw = parseDatasetJson(canvas.dataset.prompts, []);
              var prompts = Array.isArray(promptsRaw) ? promptsRaw : [];

              function nodeId(node) { return 'prompt-flow-node-' + node.id; }

              function createNodeElement(node) {
                var el = document.createElement('div');
                el.id = nodeId(node);
                el.className = 'prompt-flow-node pf-node pf-node--' + node.node_type;
                el.dataset.nodeId = node.id;
                el.style.position = 'absolute';
                el.style.left = (node.position_x || 40) + 'px';
                el.style.top = (node.position_y || 40) + 'px';

                var titleHtml = '<div class=\"pf-node__header\"><span>' + node.node_type + '</span><span></span></div>';
                var bodyHtml = '<div class=\"pf-node__body\">';

                if (node.node_type === 'input') {
                  var value = node.config && node.config.param_key ? node.config.param_key : '';
                  bodyHtml += '<div class=\"pf-node__row\"><span>' + (value || 'param') + '</span><span></span></div>';
                }

                if (node.node_type === 'prompt') {
                  var options = '';
                  if (prompts.length) {
                    options = prompts.map(function(p) {
                      var selected = String(node.prompt_id) === String(p.id) ? 'selected' : '';
                      return '<option value=\"' + p.id + '\" ' + selected + '>' + p.name + '</option>';
                    }).join('');
                  } else {
                    var fallbackLabel = node.prompt_id ? ('Prompt #' + node.prompt_id) : 'Prompt';
                    options = '<option value=\"\" selected>' + fallbackLabel + '</option>';
                  }
                  bodyHtml += '<div><select class=\"pf-node__input\" disabled>' + options + '</select></div>';
                  bodyHtml += '<div class=\"pf-node__row\"><span>Response</span><span></span></div>';
                  bodyHtml += '<div class=\"pf-node__inputs\">';
                  Object.keys(node.input_ports || {}).forEach(function(port) {
                    bodyHtml += '<div class=\"pf-node__row\"><span>' + port + '</span><span></span></div>';
                  });
                  bodyHtml += '</div>';
                }

                if (node.node_type === 'output') {
                  bodyHtml += '<div class=\"pf-node__row\"><span>Response</span><span></span></div>';
                }

                bodyHtml += '</div>';
                el.innerHTML = titleHtml + bodyHtml;
                canvas.appendChild(el);
                return el;
              }

              var flowOutEndpoint = {
                endpoint: tk.DotEndpoint.type,
                paintStyle: { stroke: '#ffffff', fill: '#ffffff', radius: 8, strokeWidth: 2 },
                source: true,
                maxConnections: 1,
                connector: {
                  type: 'Flowchart',
                  options: { stub: [40, 60], gap: 10, cornerRadius: 5, alwaysRespectStubs: true }
                }
              };

              var flowInEndpoint = {
                endpoint: tk.DotEndpoint.type,
                paintStyle: { stroke: '#ffffff', fill: 'transparent', radius: 8, strokeWidth: 2 },
                target: true,
                maxConnections: -1
              };

              var varOutEndpoint = {
                endpoint: tk.DotEndpoint.type,
                paintStyle: { stroke: '#16a34a', fill: '#16a34a', radius: 6, strokeWidth: 1 },
                source: true,
                maxConnections: -1
              };

              var varInEndpoint = {
                endpoint: tk.DotEndpoint.type,
                paintStyle: { stroke: '#16a34a', fill: '#16a34a', radius: 6, strokeWidth: 1 },
                target: true,
                maxConnections: 1
              };

              function addPorts(node, el) {
                var inputPorts = Object.keys(node.input_ports || {});
                var outputPorts = Object.keys(node.output_ports || {});
                var rowHeight = 26;
                var flowBaseOffset = 15;
                var varBaseOffsetDefault = flowBaseOffset + 35;
                var varBaseOffsetInput = flowBaseOffset + 40;
                var varBaseOffsetPrompt = flowBaseOffset + 71;

                function leftAnchorAt(row, baseOffset) {
                  return [0, 0, -1, 0, 0, baseOffset + row * rowHeight];
                }

                function rightAnchorAt(row, baseOffset) {
                  return [1, 0, 1, 0, 0, baseOffset + row * rowHeight];
                }

                if (node.node_type === 'start') {
                  instance.addEndpoint(el, flowOutEndpoint, {
                    anchor: rightAnchorAt(0, flowBaseOffset),
                    uuid: node.id + '-flow-out'
                  });
                  return;
                }

                if (node.node_type === 'output') {
                  instance.addEndpoint(el, flowInEndpoint, {
                    anchor: leftAnchorAt(0, flowBaseOffset),
                    uuid: node.id + '-flow-in'
                  });
                  instance.addEndpoint(el, varInEndpoint, {
                    anchor: leftAnchorAt(0, varBaseOffsetDefault),
                    uuid: node.id + '-in-response'
                  });
                  return;
                }

                if (node.node_type === 'input') {
                  outputPorts.forEach(function(port) {
                    instance.addEndpoint(el, varOutEndpoint, {
                      anchor: rightAnchorAt(0, varBaseOffsetInput),
                      uuid: node.id + '-out-' + port
                    });
                  });
                  return;
                }

                if (node.node_type === 'prompt') {
                  instance.addEndpoint(el, flowInEndpoint, {
                    anchor: leftAnchorAt(0, flowBaseOffset),
                    uuid: node.id + '-flow-in'
                  });
                  instance.addEndpoint(el, flowOutEndpoint, {
                    anchor: rightAnchorAt(0, flowBaseOffset),
                    uuid: node.id + '-flow-out'
                  });
                  instance.addEndpoint(el, varOutEndpoint, {
                    anchor: rightAnchorAt(0, varBaseOffsetPrompt),
                    uuid: node.id + '-out-response'
                  });
                  inputPorts.forEach(function(port, index) {
                    instance.addEndpoint(el, varInEndpoint, {
                      anchor: leftAnchorAt(index + 1, varBaseOffsetPrompt),
                      uuid: node.id + '-in-' + port
                    });
                  });
                }
              }

              instance.batch(function() {
                nodes.forEach(function(node) {
                  var el = createNodeElement(node);
                  addPorts(node, el);
                  instance.manage(el);
                });

                edges.forEach(function(edge) {
                  var sourceUuid = edge.source_port === 'flow'
                    ? edge.source_node_id + '-flow-out'
                    : edge.source_node_id + '-out-' + edge.source_port;
                  var targetUuid = edge.target_port === 'flow'
                    ? edge.target_node_id + '-flow-in'
                    : edge.target_node_id + '-in-' + edge.target_port;
                  instance.connect({ uuids: [sourceUuid, targetUuid] });
                });
              });

              if (!editable) {
                if (typeof instance.bind === 'function') {
                  instance.bind('beforeDrop', function() { return false; });
                  instance.bind('beforeDetach', function() { return false; });
                }
                nodes.forEach(function(node) {
                  var el = document.getElementById(nodeId(node));
                  if (!el) { return; }
                  if (typeof instance.setDraggable === 'function') {
                    instance.setDraggable(el, false);
                  }
                  el.style.cursor = 'default';
                });
                canvas.querySelectorAll('input, select, textarea, button').forEach(function(el) {
                  el.setAttribute('disabled', 'disabled');
                });
                canvas.querySelectorAll('.jtk-endpoint, .jtk-connector').forEach(function(el) {
                  el.style.pointerEvents = 'none';
                });
              }
            }

            loadJsPlumb(function() {
              window.jsPlumb.ready(initCanvas);
            });
          })();
        JS
      end
    end

    panel 'Versions' do
      table_for resource.versions do
        column :version_number do |flow|
          if flow.is_current?
            strong flow.version_number
          else
            flow.version_number
          end
        end
        column :status do |flow|
          display_status = if flow.is_current?
                             'active'
                           elsif flow.status == 'invalid'
                             'invalid'
                           else
                             'draft'
                           end
          status_tag display_status
        end
        column :created_at
        column :updated_at
        column('Actions') do |flow|
          links = []
          links << link_to('View', admin_prompt_flow_path(flow))
          links << link_to(
            'Duplicate',
            duplicate_admin_prompt_flow_path(flow),
            method: :post,
            data: { confirm: 'Create a new draft from this version?' }
          )
          unless flow.is_current?
            links << link_to(
              'Activate',
              activate_admin_prompt_flow_path(flow),
              method: :patch,
              data: { confirm: 'Set this version as the active prompt flow?' }
            )
          end
          safe_join(links, ' | ')
        end
      end
    end
  end
end
