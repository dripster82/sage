module KnowledgeGraph
  class BuildService
    include DebuggableService

    def initialize(document)
      @document = document
      @nodes_and_edges = []
      @cyphers = []
      @category_validation_prompt = Prompt.find_by(name: "kg_extraction_category_validation")
    end

    def process
      process_with_llm   
      # validate_node_categories
      validate_nodes_with_llm
      save_chunk_nodes_and_edges 
    end
    
    private

    def validate_nodes_with_llm
      llm_validation_service = KnowledgeGraph::LlmValidationService.new(@nodes_and_edges)
      @nodes_and_edges = llm_validation_service.validate_nodes
    end

    def validate_node_categories
      category_nodes = @nodes_and_edges["nodes"].select { |node| node["type"].to_s.upcase == "CATEGORY" }
      return if category_nodes.empty?

      # Prepare the prompt on the category validation service
      replacement_hash = @category_validation_prompt.tags_hash.tap do |h|
        h[:categories] = category_nodes.map { |c| c["name"] }.join(", ")
        h[:summary] = @document.summary
      end

      query = @category_validation_prompt.content % replacement_hash
      json_data = Llm::QueryService.new.json_from_query(query)

      category_mapping = json_data["cats"].to_h do |mapping|
        [mapping["orig_cat"], mapping["new_cat"]]
      end

      # Update edges with new category names
      @nodes_and_edges["edges"].each do |edge|
        edge["target"] = category_mapping[edge["target"]] if edge["target_type"].to_s.upcase == "CATEGORY" && category_mapping.key?(edge["target"])
        edge["source"] = category_mapping[edge["source"]] if edge["source_type"].to_s.upcase == "CATEGORY" && category_mapping.key?(edge["source"])
      end

      # Remove unused category nodes
      used_categories = category_mapping.values.uniq
      all_categories = category_mapping.keys
      unused_categories = all_categories - used_categories
      @nodes_and_edges["nodes"].reject! do |node|
        node["type"].to_s.upcase == "CATEGORY" && unused_categories.include?(node["name"])
      end

      # Update remaining category node names
      @nodes_and_edges["nodes"].each do |node|
        if node["type"].to_s.upcase == "CATEGORY" && category_mapping.key?(node["name"])
          node["name"] = category_mapping[node["name"]]
        end
      end
    end

    def save_chunk_nodes_and_edges
      build_node_cyphers
      build_edge_cyphers
      save_cyphers
    end

    def save_cyphers
      debug_log "Saving cyphers"
      @cyphers.each do |cypher|
        KnowledgeGraph::QueryService.new.query(cypher) 
      rescue  => e
        debug_log "Failed to run cypher: #{cypher}"
        debug_log "Error: #{e.message}"
        debug_log e.backtrace.join("\n")
      end
      File.write("final_cyphers.txt", @cyphers.join("\n"))
      debug_log "Cyphers saved"
    end

    def build_edge_cyphers 
      edge_template = <<~TEMPLATE
          MATCH (source:%{source_type} { name: "%{source_name}" })
          MATCH (target:%{target_type} { name: "%{target_name}" })
          MERGE (source)-[r:%{type}]->(target)%{attributes_clause}
        TEMPLATE
        attributes_clause = <<~TEMPLATE

          ON CREATE SET %{attributes}
          ON MATCH SET %{attributes}
      TEMPLATE
      edges_cyphers = @nodes_and_edges["edges"].each_with_object([]) do |edge, cyphers|
        attribute_pattern = nil
        if edge.has_key?("relationship_description")
          relationship_description = edge["relationship_description"]
          relationship_description = relationship_description.is_a?(String) ? relationship_description.gsub('"', '\"') : relationship_description
          attribute_pattern = attributes_clause % { attributes: "r.description = \"#{relationship_description}\"" }
        end
        debug_log "Edge: #{edge}"
        cypher = edge_template % { 
          source_type: edge["source_type"].upcase, 
          source_name: edge["source"].gsub('"', '\"'), 
          target_type: edge["target_type"].upcase, 
          target_name: edge["target"].gsub('"', '\"'), 
          type: edge["relationship_type"], 
          attributes_clause: attribute_pattern 
        }
        cyphers << cypher.strip + ";"
        # kg_service.query(cypher)
        debug_log cypher
      rescue => e
        debug_log "Failed to build edge cypher: #{e.message}"
        debug_log e.backtrace.take(4).join("\n")
      end
      @cyphers += edges_cyphers
    end

    def build_node_cyphers
      node_template = <<~TEMPLATE
          MERGE (n:%{type} { name: "%{name}" })%{attributes_clause}
        TEMPLATE
      attributes_clause = <<~TEMPLATE

          ON CREATE SET %{attributes}
          ON MATCH SET %{attributes}
      TEMPLATE
      
      node_cyphers = @nodes_and_edges["nodes"].each_with_object([]) do |node, cyphers|
        attribute_pattern = nil
        if node.has_key?("description")
          description = node["description"]
          description = description.is_a?(String) ? description.gsub('"', '\"') : description
          attribute_pattern = attributes_clause % { attributes: "n.description = \"#{description}\"" }
        end
        cypher = node_template % { type: node["type"].upcase, name: node["name"].gsub('"', '\"'), attributes_clause: attribute_pattern }
        cyphers << cypher.strip + ";"
        # kg_service.query(cypher)
        debug_log cypher
      end 

      @cyphers += node_cyphers
    end

    def process_with_llm
      llm_extraction_service = KnowledgeGraph::LlmExtractionService.new(@document)
      @nodes_and_edges = llm_extraction_service.process
    end
  end
end