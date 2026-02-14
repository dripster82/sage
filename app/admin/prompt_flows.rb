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
    nodes_json = flow.persisted? ? flow.nodes.as_json(only: %i[id node_type prompt_id position_x position_y input_ports output_ports]) : []
    edges_json = flow.persisted? ? flow.edges.as_json(only: %i[id source_node_id target_node_id source_port target_port]) : []

    f.inputs do
      f.input :name
      f.input :description, as: :string
      f.input :status, as: :select, collection: %w[draft valid invalid]
      f.input :max_executions
    end

    panel 'Flow Canvas' do
      div id: 'prompt-flow-canvas',
          data: {
            editable: true,
            flow_id: flow.persisted? ? flow.id : nil,
            nodes: nodes_json,
            edges: edges_json,
            update_node_url: flow.persisted? ? update_node_position_admin_prompt_flow_path(flow) : nil,
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

              if (nodes.length < 2) {
                nodes = [
                  {
                    id: 'demo-left',
                    node_type: 'input',
                    position_x: 60,
                    position_y: 80,
                    input_ports: { in: {} },
                    output_ports: { out: {} }
                  },
                  {
                    id: 'demo-right',
                    node_type: 'output',
                    position_x: 340,
                    position_y: 80,
                    input_ports: { in: {} },
                    output_ports: { out: {} }
                  }
                ];
                edges = [
                  {
                    source_node_id: 'demo-left',
                    target_node_id: 'demo-right',
                    source_port: 'out',
                    target_port: 'in'
                  }
                ];
              }

              if (nodes.length < 2) {
                nodes = [
                  {
                    id: 'demo-left',
                    node_type: 'input',
                    position_x: 60,
                    position_y: 80,
                    input_ports: { in: {} },
                    output_ports: { out: {} }
                  },
                  {
                    id: 'demo-right',
                    node_type: 'output',
                    position_x: 340,
                    position_y: 80,
                    input_ports: { in: {} },
                    output_ports: { out: {} }
                  }
                ];
                edges = [
                  {
                    source_node_id: 'demo-left',
                    target_node_id: 'demo-right',
                    source_port: 'out',
                    target_port: 'in'
                  }
                ];
              }
              var updateNodeUrl = canvas.dataset.updateNodeUrl;
              var createEdgeUrl = canvas.dataset.createEdgeUrl;
              var deleteEdgeUrl = canvas.dataset.deleteEdgeUrl;
              var csrfToken = document.querySelector('meta[name=\"csrf-token\"]')?.getAttribute('content');

              function nodeId(node) { return 'prompt-flow-node-' + node.id; }

              function createNodeElement(node) {
                var el = document.createElement('div');
                el.id = nodeId(node);
                el.className = 'prompt-flow-node prompt-flow-node--' + node.node_type;
                el.dataset.nodeId = node.id;
                el.style.position = 'absolute';
                el.style.left = (node.position_x || 40) + 'px';
                el.style.top = (node.position_y || 40) + 'px';
                el.style.minWidth = '140px';
                el.style.padding = '8px';
                el.style.border = '1px solid #d1d5db';
                el.style.borderRadius = '6px';
                el.style.background = '#fff';
                el.style.boxShadow = '0 1px 2px rgba(0,0,0,0.06)';
                if (node.node_type === 'input') {
                  el.style.borderColor = '#15803d';
                  el.style.background = '#86efac';
                }
                if (node.node_type === 'output') {
                  el.style.borderColor = '#b91c1c';
                  el.style.background = '#fca5a5';
                }
                el.innerHTML = '<div class=\"prompt-flow-node__title\">' + node.node_type + '</div>';
                canvas.appendChild(el);
                return el;
              }

              var sourceEndpoint = {
                endpoint: tk.DotEndpoint.type,
                paintStyle: { stroke: '#7AB02C', fill: 'transparent', radius: 6, strokeWidth: 1 },
                source: true,
                maxConnections: -1,
                connector: {
                  type: 'Flowchart',
                  options: { stub: [40, 60], gap: 10, cornerRadius: 5, alwaysRespectStubs: true }
                }
              };

              var targetEndpoint = {
                endpoint: tk.DotEndpoint.type,
                paintStyle: { fill: '#7AB02C', radius: 6 },
                target: true,
                maxConnections: 1
              };

              function addPorts(node, el) {
                var inputPorts = Object.keys(node.input_ports || {});
                var outputPorts = Object.keys(node.output_ports || {});

                inputPorts.forEach(function(port) {
                  instance.addEndpoint(el, targetEndpoint, {
                    anchor: tk.AnchorLocations.Left,
                    uuid: node.id + '-in-' + port
                  });
                });

                outputPorts.forEach(function(port) {
                  instance.addEndpoint(el, sourceEndpoint, {
                    anchor: tk.AnchorLocations.Right,
                    uuid: node.id + '-out-' + port
                  });
                });
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
                if (sourcePort !== 'output' || targetPort !== 'input') { return false; }
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

              if (!document.getElementById('prompt-flow-node-demo-right')) {
                var fallbackEl = document.createElement('div');
                fallbackEl.id = 'prompt-flow-node-demo-right';
                fallbackEl.className = 'prompt-flow-node prompt-flow-node--output';
                fallbackEl.style.position = 'absolute';
                fallbackEl.style.left = '340px';
                fallbackEl.style.top = '80px';
                fallbackEl.style.minWidth = '140px';
                fallbackEl.style.padding = '8px';
                fallbackEl.style.border = '1px solid #b91c1c';
                fallbackEl.style.borderRadius = '6px';
                fallbackEl.style.background = '#fca5a5';
                fallbackEl.style.boxShadow = '0 1px 2px rgba(0,0,0,0.06)';
                fallbackEl.innerHTML = '<div class=\"prompt-flow-node__title\">output</div>';
                canvas.appendChild(fallbackEl);
              }
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
                el.className = 'prompt-flow-node prompt-flow-node--' + node.node_type;
                el.dataset.nodeId = node.id;
                el.style.position = 'absolute';
                el.style.left = (node.position_x || 40) + 'px';
                el.style.top = (node.position_y || 40) + 'px';
                el.style.minWidth = '140px';
                el.style.padding = '8px';
                el.style.border = '1px solid #d1d5db';
                el.style.borderRadius = '6px';
                el.style.background = '#fff';
                el.style.boxShadow = '0 1px 2px rgba(0,0,0,0.06)';
                if (node.node_type === 'input') {
                  el.style.borderColor = '#15803d';
                  el.style.background = '#86efac';
                }
                if (node.node_type === 'output') {
                  el.style.borderColor = '#b91c1c';
                  el.style.background = '#fca5a5';
                }
                el.innerHTML = '<div class=\"prompt-flow-node__title\">' + node.node_type + '</div>';
                canvas.appendChild(el);
                return el;
              }

              var sourceEndpoint = {
                endpoint: tk.DotEndpoint.type,
                paintStyle: { stroke: '#7AB02C', fill: 'transparent', radius: 6, strokeWidth: 1 },
                source: true,
                maxConnections: -1,
                connector: {
                  type: 'Flowchart',
                  options: { stub: [40, 60], gap: 10, cornerRadius: 5, alwaysRespectStubs: true }
                }
              };

              var targetEndpoint = {
                endpoint: tk.DotEndpoint.type,
                paintStyle: { fill: '#7AB02C', radius: 6 },
                target: true,
                maxConnections: 1
              };

              function addPorts(node, el) {
                var inputPorts = Object.keys(node.input_ports || {});
                var outputPorts = Object.keys(node.output_ports || {});

                inputPorts.forEach(function(port) {
                  instance.addEndpoint(el, targetEndpoint, {
                    anchor: tk.AnchorLocations.Left,
                    uuid: node.id + '-in-' + port
                  });
                });

                outputPorts.forEach(function(port) {
                  instance.addEndpoint(el, sourceEndpoint, {
                    anchor: tk.AnchorLocations.Right,
                    uuid: node.id + '-out-' + port
                  });
                });
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

              if (!document.getElementById('prompt-flow-node-demo-right')) {
                var fallbackEl = document.createElement('div');
                fallbackEl.id = 'prompt-flow-node-demo-right';
                fallbackEl.className = 'prompt-flow-node prompt-flow-node--output';
                fallbackEl.style.position = 'absolute';
                fallbackEl.style.left = '340px';
                fallbackEl.style.top = '80px';
                fallbackEl.style.minWidth = '140px';
                fallbackEl.style.padding = '8px';
                fallbackEl.style.border = '1px solid #b91c1c';
                fallbackEl.style.borderRadius = '6px';
                fallbackEl.style.background = '#fca5a5';
                fallbackEl.style.boxShadow = '0 1px 2px rgba(0,0,0,0.06)';
                fallbackEl.innerHTML = '<div class=\"prompt-flow-node__title\">output</div>';
                canvas.appendChild(fallbackEl);
              }
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
