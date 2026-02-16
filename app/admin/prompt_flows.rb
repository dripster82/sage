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

  member_action :update_node_position, method: :patch do
    node = resource.nodes.find(params[:node_id])
    node.update!(
      position_x: params[:position_x],
      position_y: params[:position_y]
    )

    render json: { success: true }
  end

  member_action :create_node, method: :post do
    node = resource.nodes.create!(
      node_type: params[:node_type],
      prompt_id: params[:prompt_id],
      position_x: params[:position_x],
      position_y: params[:position_y],
      config: params[:config] || {},
      input_ports: params[:input_ports] || {},
      output_ports: params[:output_ports] || {}
    )

    render json: { success: true, node: node.as_json }
  end

  member_action :update_node, method: :patch do
    node = resource.nodes.find(params[:node_id])
    node.update!(
      prompt_id: params[:prompt_id],
      config: params[:config] || node.config,
      input_ports: params[:input_ports] || node.input_ports,
      output_ports: params[:output_ports] || node.output_ports
    )

    render json: { success: true, node: node.as_json }
  end

  member_action :create_edge, method: :post do
    edge = resource.edges.create!(
      source_node_id: params[:source_node_id],
      target_node_id: params[:target_node_id],
      source_port: params[:source_port],
      target_port: params[:target_port],
      validation_status: params[:validation_status]
    )

    render json: { success: true, edge: edge.as_json }
  end

  member_action :delete_edge, method: :delete do
    edge = if params[:edge_id].present?
             resource.edges.find_by(id: params[:edge_id])
           else
             resource.edges.find_by(
               source_node_id: params[:source_node_id],
               target_node_id: params[:target_node_id],
               source_port: params[:source_port],
               target_port: params[:target_port]
             )
           end

    edge&.destroy

    render json: { success: true }
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
    flow = f.object
    nodes_json = (flow.persisted? ? flow.nodes.as_json(only: %i[id node_type prompt_id position_x position_y input_ports output_ports]) : []).to_json
    edges_json = (flow.persisted? ? flow.edges.as_json(only: %i[id source_node_id target_node_id source_port target_port]) : []).to_json
    prompts_json = Prompt.order(:name).map { |p| { id: p.id, name: p.name, tags: p.tags_list } }.to_json

    f.inputs do
      f.input :name
      f.input :description, as: :string
      f.input :status, as: :select, collection: %w[draft valid invalid]
      f.input :max_executions
    end

    panel 'Flow Canvas' do
      div do
        style do
          raw <<~CSS
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
        end
      end

      div class: 'prompt-flow-palette', style: 'display:flex; gap:8px; margin-bottom:12px;' do
        button 'Add Input', type: 'button', id: 'prompt-flow-add-input', class: 'button'
        button 'Add Prompt', type: 'button', id: 'prompt-flow-add-prompt', class: 'button'
      end

      div id: 'prompt-flow-canvas',
          data: {
            editable: true,
            flow_id: flow.persisted? ? flow.id : nil,
            nodes: nodes_json,
            edges: edges_json,
            prompts: prompts_json,
            update_node_url: flow.persisted? ? update_node_position_admin_prompt_flow_path(flow) : nil,
            create_node_url: flow.persisted? ? create_node_admin_prompt_flow_path(flow) : nil,
            update_node_url_full: flow.persisted? ? update_node_admin_prompt_flow_path(flow) : nil,
            create_edge_url: flow.persisted? ? create_edge_admin_prompt_flow_path(flow) : nil,
            delete_edge_url: flow.persisted? ? delete_edge_admin_prompt_flow_path(flow) : nil
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
              var nodes = JSON.parse(canvas.dataset.nodes || '[]');
              var edges = JSON.parse(canvas.dataset.edges || '[]');
              var prompts = JSON.parse(canvas.dataset.prompts || '[]');

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


              var updateNodeUrl = canvas.dataset.updateNodeUrl;
              var createNodeUrl = canvas.dataset.createNodeUrl;
              var updateNodeFullUrl = canvas.dataset.updateNodeUrlFull;
              var createEdgeUrl = canvas.dataset.createEdgeUrl;
              var deleteEdgeUrl = canvas.dataset.deleteEdgeUrl;
              var csrfToken = document.querySelector('meta[name=\"csrf-token\"]')?.getAttribute('content');

              function nodeId(node) { return 'prompt-flow-node-' + node.id; }

              function createNodeElement(node) {
                var el = document.createElement('div');
                el.id = nodeId(node);
                el.className = 'prompt-flow-node pf-node pf-node--' + node.node_type;
                el.dataset.nodeId = node.id;
                el.style.position = 'absolute';
                el.style.left = (node.position_x || 40) + 'px';
                el.style.top = (node.position_y || 40) + 'px';
                var leftFlow = (node.node_type === 'start' || node.node_type === 'prompt' || node.node_type === 'output') ? '&gt;' : '';
                var rightFlow = (node.node_type === 'start' || node.node_type === 'prompt' || node.node_type === 'input') ? '&gt;' : '';
                var titleHtml = '<div class=\"pf-node__header\"><span>' + node.node_type + '</span><span></span></div>';
                var bodyHtml = '<div class=\"pf-node__body\">';

                if (node.node_type === 'input') {
                  var value = (node.config && node.config.param_key) ? node.config.param_key : '';
                  bodyHtml += '<div><input class=\"prompt-flow-node__param pf-node__input\" data-node-id=\"' + node.id + '\" placeholder=\"param key\" value=\"' + value + '\" /></div>';
                }

                if (node.node_type === 'prompt') {
                  var options = prompts.map(function(p) {
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

              function persistNodePosition(nodeEl) {
                if (!editable || !updateNodeUrl) { return; }
                var body = JSON.stringify({
                  node_id: nodeEl.dataset.nodeId,
                  position_x: nodeEl.offsetLeft,
                  position_y: nodeEl.offsetTop
                });

                fetch(updateNodeUrl, {
                  method: 'PATCH',
                  headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': csrfToken
                  },
                  body: body
                });
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

              instance.bind('connection', function(info) {
                if (!editable || !createEdgeUrl) { return; }

                var sourcePort = info.connection.endpoints[0].getParameter('portKey');
                var targetPort = info.connection.endpoints[1].getParameter('portKey');

                fetch(createEdgeUrl, {
                  method: 'POST',
                  headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': csrfToken
                  },
                  body: JSON.stringify({
                    source_node_id: info.connection.source.dataset.nodeId,
                    target_node_id: info.connection.target.dataset.nodeId,
                    source_port: sourcePort,
                    target_port: targetPort
                  })
                }).then(function(resp) { return resp.json(); }).then(function(data) {
                  if (data && data.edge && data.edge.id) {
                    info.connection.edgeId = data.edge.id;
                  }
                });
              });

              instance.bind('connectionDetached', function(info) {
                if (!editable || !deleteEdgeUrl) { return; }

                var sourcePort = info.connection.endpoints[0].getParameter('portKey');
                var targetPort = info.connection.endpoints[1].getParameter('portKey');

                fetch(deleteEdgeUrl, {
                  method: 'DELETE',
                  headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': csrfToken
                  },
                  body: JSON.stringify({
                    edge_id: info.connection.edgeId,
                    source_node_id: info.connection.source.dataset.nodeId,
                    target_node_id: info.connection.target.dataset.nodeId,
                    source_port: sourcePort,
                    target_port: targetPort
                  })
                });
              });

              function updatePromptPorts(node, el, promptId, promptName) {
                console.log('[PromptFlow] updatePromptPorts start', { nodeId: node && node.id, promptId: promptId, promptName: promptName });
                var prompt = prompts.find(function(p) { return p.id == promptId; });
                if (!prompt && promptName) {
                  prompt = prompts.find(function(p) { return p.name === promptName; });
                }
                console.log('[PromptFlow] resolved prompt', prompt);
                var tags = prompt && prompt.tags ? prompt.tags : [];
                console.log('[PromptFlow] tags', tags);
                node.prompt_id = promptId;
                node.input_ports = tags.reduce(function(acc, tag) {
                  acc[tag] = {};
                  return acc;
                }, {});
                node.output_ports = { response: {} };

                console.log('[PromptFlow] removing endpoints', el);
                instance.removeAllEndpoints(el);
                console.log('[PromptFlow] adding ports');
                addPorts(node, el);

                var inputsEl = el.querySelector('.pf-node__inputs');
                if (!inputsEl) {
                  inputsEl = document.createElement('div');
                  inputsEl.className = 'pf-node__inputs';
                  el.querySelector('.pf-node__body')?.appendChild(inputsEl);
                }

                console.log('[PromptFlow] rebuilding inputs list');
                inputsEl.innerHTML = '';
                Object.keys(node.input_ports || {}).forEach(function(port) {
                  var row = document.createElement('div');
                  row.className = 'pf-node__row';
                  row.innerHTML = '<span>' + port + '</span><span></span>';
                  inputsEl.appendChild(row);
                });

                if (editable && updateNodeFullUrl) {
                  console.log('[PromptFlow] persisting prompt ports');
                  fetch(updateNodeFullUrl, {
                    method: 'PATCH',
                    headers: {
                      'Content-Type': 'application/json',
                      'X-CSRF-Token': csrfToken
                    },
                    body: JSON.stringify({
                      node_id: node.id,
                      prompt_id: node.prompt_id,
                      input_ports: node.input_ports,
                      output_ports: node.output_ports
                    })
                  });
                }
              }

              function updateInputParam(node, el, value) {
                node.config = node.config || {};
                node.config.param_key = value;
                node.output_ports = {};
                if (value) { node.output_ports[value] = {}; }

                instance.removeAllEndpoints(el);
                addPorts(node, el);

                if (editable && updateNodeFullUrl) {
                  fetch(updateNodeFullUrl, {
                    method: 'PATCH',
                    headers: {
                      'Content-Type': 'application/json',
                      'X-CSRF-Token': csrfToken
                    },
                    body: JSON.stringify({
                      node_id: node.id,
                      config: node.config,
                      output_ports: node.output_ports
                    })
                  });
                }
              }

              function enableDrag(el) {
                if (typeof instance.draggable === 'function') {
                  instance.draggable(el, {
                    stop: function(params) {
                      persistNodePosition(params.el);
                    }
                  });
                  return;
                }
              }

              instance.batch(function() {
                nodes.forEach(function(node) {
                  var el = createNodeElement(node);
                  addPorts(node, el);
                  if (editable) { instance.manage(el); }
                  if (node.node_type === 'prompt') {
                    var select = el.querySelector('.prompt-flow-node__prompt');
                    if (select) {
                      select.addEventListener('change', function(event) {
                        var value = parseInt(event.target.value, 10);
                        var name = event.target.options[event.target.selectedIndex]?.text || null;
                        console.log('[PromptFlow] select change (direct listener)', { nodeId: node.id, value: value, name: name });
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
                  var sourceUuid = edge.source_node_id + '-out-' + edge.source_port;
                  var targetUuid = edge.target_node_id + '-in-' + edge.target_port;
                  var connection = instance.connect({ uuids: [sourceUuid, targetUuid] });
                  if (connection && edge.id) {
                    connection.edgeId = edge.id;
                  }
                });
              });

              // Removed fallback node injection; only render actual nodes.

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

                if (editable && createNodeUrl) {
                  fetch(createNodeUrl, {
                    method: 'POST',
                    headers: {
                      'Content-Type': 'application/json',
                      'X-CSRF-Token': csrfToken
                    },
                    body: JSON.stringify({
                      node_type: node.node_type,
                      prompt_id: node.prompt_id,
                      position_x: node.position_x,
                      position_y: node.position_y,
                      config: node.config,
                      input_ports: node.input_ports,
                      output_ports: node.output_ports
                    })
                  }).then(function(resp) { return resp.json(); }).then(function(data) {
                    if (!data || !data.node) { return; }
                    node.id = data.node.id;
                    var el = createNodeElement(node);
                    addPorts(node, el);
                    instance.manage(el);
                    if (node.node_type === 'prompt') {
                      var select = el.querySelector('.prompt-flow-node__prompt');
                      if (select) {
                        select.addEventListener('change', function(event) {
                          var value = parseInt(event.target.value, 10);
                          var name = event.target.options[event.target.selectedIndex]?.text || null;
                          console.log('[PromptFlow] select change (new node)', { nodeId: node.id, value: value, name: name });
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
                } else {
                  var el = createNodeElement(node);
                  addPorts(node, el);
                  instance.manage(el);
                }
              }

              var addInputBtn = document.getElementById('prompt-flow-add-input');
              var addPromptBtn = document.getElementById('prompt-flow-add-prompt');
              if (addInputBtn) { addInputBtn.addEventListener('click', function() { createNodeFromPalette('input'); }); }
              if (addPromptBtn) { addPromptBtn.addEventListener('click', function() { createNodeFromPalette('prompt'); }); }

              canvas.addEventListener('change', function(event) {
                var select = event.target.closest('.prompt-flow-node__prompt');
                if (!select) { return; }
                var nodeIdValue = select.getAttribute('data-node-id');
                var node = nodes.find(function(n) { return n.id == nodeIdValue; });
                if (!node) {
                  console.log('[PromptFlow] delegated change: node not found', nodeIdValue, nodes);
                  return;
                }
                var value = parseInt(select.value, 10);
                var name = select.options[select.selectedIndex]?.text || null;
                console.log('[PromptFlow] select change (delegated)', { nodeId: node.id, value: value, name: name });
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
    nodes_json = resource.nodes.as_json(only: %i[id node_type prompt_id position_x position_y input_ports output_ports])
    edges_json = resource.edges.as_json(only: %i[id source_node_id target_node_id source_port target_port])

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
      div do
        style do
          raw <<~CSS
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
            }
            .pf-node__body {
              padding: 8px 10px;
              display: grid;
              gap: 6px;
            }
            .pf-node__row {
              display: flex;
              align-items: center;
              justify-content: space-between;
              gap: 8px;
              color: #cbd5f5;
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
            .pf-node--start .pf-node__header { color: #93c5fd; }
            .pf-node--input .pf-node__header { color: #86efac; }
            .pf-node--output .pf-node__header { color: #fca5a5; }
            .pf-node--prompt .pf-node__header { color: #fcd34d; }
          CSS
        end
      end
      div id: 'prompt-flow-canvas',
          data: {
            editable: false,
            flow_id: resource.id,
            nodes: nodes_json,
            edges: edges_json
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

              var nodes = JSON.parse(canvas.dataset.nodes || '[]');
              var edges = JSON.parse(canvas.dataset.edges || '[]');

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

                if (node.node_type === 'prompt') {
                  bodyHtml += '<div class=\"pf-node__row\"><span>Response</span><span></span></div>';
                  Object.keys(node.input_ports || {}).forEach(function(port) {
                    bodyHtml += '<div class=\"pf-node__row\"><span>' + port + '</span><span></span></div>';
                  });
                }

                if (node.node_type === 'output') {
                  bodyHtml += '<div class=\"pf-node__row\"><span>response</span><span></span></div>';
                }

                bodyHtml += '</div>';
                el.innerHTML = titleHtml + bodyHtml;
                canvas.appendChild(el);
                return el;
              }

              var sourceEndpoint = {
                endpoint: tk.DotEndpoint.type,
                paintStyle: { stroke: '#7AB02C', fill: 'transparent', radius: 6, strokeWidth: 1 },
                source: true,
                maxConnections: 1,
                connector: {
                  type: 'Flowchart',
                  options: { stub: [40, 60], gap: 10, cornerRadius: 5, alwaysRespectStubs: true }
                }
              };

              var targetEndpoint = {
                endpoint: tk.DotEndpoint.type,
                paintStyle: { fill: '#7AB02C', radius: 6 },
                target: true,
                maxConnections: -1
              };

              function addPorts(node, el) {
                var inputPorts = Object.keys(node.input_ports || {});
                var outputPorts = Object.keys(node.output_ports || {});
                var rowHeight = 26;
                var flowBaseOffset = 15;
                var varBaseOffsetDefault = flowBaseOffset + 35;
                var varBaseOffsetPrompt = flowBaseOffset + 53;

                function leftAnchorAt(row, baseOffset) {
                  return [0, 0, -1, 0, 0, baseOffset + row * rowHeight];
                }

                function rightAnchorAt(row, baseOffset) {
                  return [1, 0, 1, 0, 0, baseOffset + row * rowHeight];
                }

                if (node.node_type === 'start') {
                  instance.addEndpoint(el, sourceEndpoint, {
                    anchor: rightAnchorAt(0, flowBaseOffset),
                    uuid: node.id + '-flow-out'
                  });
                  return;
                }

                if (node.node_type === 'output') {
                  instance.addEndpoint(el, targetEndpoint, {
                    anchor: leftAnchorAt(0, flowBaseOffset),
                    uuid: node.id + '-flow-in'
                  });
                  instance.addEndpoint(el, targetEndpoint, {
                    anchor: leftAnchorAt(0, varBaseOffsetDefault),
                    uuid: node.id + '-in-response'
                  });
                  return;
                }

                if (node.node_type === 'input') {
                  instance.addEndpoint(el, sourceEndpoint, {
                    anchor: rightAnchorAt(0, flowBaseOffset),
                    uuid: node.id + '-flow-out'
                  });
                  outputPorts.forEach(function(port) {
                    instance.addEndpoint(el, sourceEndpoint, {
                      anchor: rightAnchorAt(0, varBaseOffsetDefault),
                      uuid: node.id + '-out-' + port
                    });
                  });
                  return;
                }

                if (node.node_type === 'prompt') {
                  instance.addEndpoint(el, targetEndpoint, {
                    anchor: leftAnchorAt(0, flowBaseOffset),
                    uuid: node.id + '-flow-in'
                  });
                  instance.addEndpoint(el, sourceEndpoint, {
                    anchor: rightAnchorAt(0, flowBaseOffset),
                    uuid: node.id + '-flow-out'
                  });
                  instance.addEndpoint(el, sourceEndpoint, {
                    anchor: rightAnchorAt(0, varBaseOffsetPrompt),
                    uuid: node.id + '-out-response'
                  });
                  inputPorts.forEach(function(port, index) {
                    instance.addEndpoint(el, targetEndpoint, {
                      anchor: leftAnchorAt(index, varBaseOffsetPrompt),
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
                  var sourceUuid = edge.source_node_id + '-out-' + edge.source_port;
                  var targetUuid = edge.target_node_id + '-in-' + edge.target_port;
                  instance.connect({ uuids: [sourceUuid, targetUuid] });
                });
              });

              // Removed fallback node injection; only render actual nodes.
            }

            loadJsPlumb(function() {
              window.jsPlumb.ready(initCanvas);
            });
          })();
        JS
      end
    end
  end
end
