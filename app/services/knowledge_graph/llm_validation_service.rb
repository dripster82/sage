module KnowledgeGraph
  class LlmValidationService
    include DebuggableService

    def initialize(nodes_and_edges)
      @model = "anthropic/claude-3.5-haiku"
      @nodes_and_edges = nodes_and_edges
    end

    def validate_nodes
      validate_nodes_with_llm 
      cleanup_nodes
    end

    private

    def cleanup_nodes
      return @nodes_and_edges unless @node_mapping&.any?

      debug_log "Starting node cleanup with #{@node_mapping.size} node mappings"

      # Parse node mapping data - create mapping from orig_node key to new_node data
      node_mapping = {}
      new_node_lookup = {}

      @node_mapping.each do |mapping|
        orig_key = "#{mapping['orig_node']['name']}|#{mapping['orig_node']['type']}"
        new_key = "#{mapping['new_node']['name']}|#{mapping['new_node']['type']}"
        node_mapping[orig_key] = mapping['new_node']
        new_node_lookup[new_key] = mapping['new_node']
        debug_log "Mapping: #{orig_key} -> #{new_key}"
      end

      # First, find and merge attributes from orig_nodes into existing new_nodes
      # Keep track of orig_nodes to remove
      orig_nodes_to_remove = []

      @nodes_and_edges["nodes"].each do |node|
        node_key = "#{node['name']}|#{node['type']}"
        next if
        # If this is an orig_node that needs to be replaced
        if node_mapping.key?(node_key) && !new_node_lookup.key?(node_key)
          orig_nodes_to_remove << node
          new_node_data = node_mapping[node_key]
          new_node_key = "#{new_node_data['name']}|#{new_node_data['type']}"

          debug_log "Removing original node: #{node_key}"

          # Find the existing new_node in the nodes array
          existing_new_node = @nodes_and_edges["nodes"].find do |n|
            "#{n['name']}|#{n['type']}" == new_node_key
          end

          # If new_node exists, merge attributes (new_node attributes take precedence)
          if existing_new_node
            debug_log "Merging attributes into existing new node: #{new_node_key}"
            if node.has_key?("attributes") && node["attributes"]&.any?
              existing_new_node["attributes"] ||= {}
              # Merge with existing new_node attributes taking precedence (no duplicates)
              merged_attributes = node["attributes"].merge(existing_new_node["attributes"])
              existing_new_node["attributes"] = merged_attributes
              debug_log "Merged attributes: #{merged_attributes.keys.join(', ')}"
            end
          else
            # If new_node doesn't exist yet, create it with merged attributes
            debug_log "Creating new node: #{new_node_key}"
            new_node = {
              "name" => new_node_data["name"],
              "type" => new_node_data["type"]
            }

            # Add attributes from orig_node if they exist
            if node.has_key?("attributes") && node["attributes"]&.any?
              new_node["attributes"] = node["attributes"].dup
              debug_log "Added attributes to new node: #{new_node['attributes'].keys.join(', ')}"
            end

            @nodes_and_edges["nodes"] << new_node
          end
        end
      end

      # Remove orig_nodes from the nodes array
      debug_log "Removing #{orig_nodes_to_remove.size} original nodes from nodes array"
      @nodes_and_edges["nodes"].reject! { |node| orig_nodes_to_remove.include?(node) }

      # Update edges to use new node references
      edges_updated = 0
      @nodes_and_edges["edges"]&.each do |edge|
        source_key = "#{edge['source']}|#{edge['source_type']}"
        target_key = "#{edge['target']}|#{edge['target_type']}"
        edge_updated = false

        # Update source if it maps to a new node
        if node_mapping.key?(source_key)
          new_source = node_mapping[source_key]
          old_source = "#{edge['source']}|#{edge['source_type']}"
          edge["source"] = new_source["name"]
          edge["source_type"] = new_source["type"]
          debug_log "Updated edge source: #{old_source} -> #{new_source['name']}|#{new_source['type']}"
          edge_updated = true
        end

        # Update target if it maps to a new node
        if node_mapping.key?(target_key)
          new_target = node_mapping[target_key]
          old_target = "#{edge['target']}|#{edge['target_type']}"
          edge["target"] = new_target["name"]
          edge["target_type"] = new_target["type"]
          debug_log "Updated edge target: #{old_target} -> #{new_target['name']}|#{new_target['type']}"
          edge_updated = true
        end

        edges_updated += 1 if edge_updated
      end

      debug_log "Node cleanup complete. Updated #{edges_updated} edges total"

      @nodes_and_edges
    end

    def validate_nodes_with_llm
      prompt = Prompt.find_by(name: "kg_node_validation")

      replacement_hash = prompt.tags_hash.tap do |h|
        h[:nodes] = @nodes_and_edges["nodes"].to_json
      end
      query = prompt.content % replacement_hash
      @node_mapping = Llm::QueryService.new(temperature: 0.4, model: @model).json_from_query(query)
    end
  end
end
