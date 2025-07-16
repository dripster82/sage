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
      merged_nodes = []

      # @node_mapping = json_data["cats"].to_h do |mapping|
      #   [mapping["orig_cat"], mapping["new_cat"]]
      # end

      # # Update edges with new category names
      # @nodes_and_edges["edges"].each do |edge|
      #   edge["target"] = category_mapping[edge["target"]] if edge["target_type"].to_s.upcase == "CATEGORY" && category_mapping.key?(edge["target"])
      #   edge["source"] = category_mapping[edge["source"]] if edge["source_type"].to_s.upcase == "CATEGORY" && category_mapping.key?(edge["source"])
      # end

      # # Remove unused category nodes
      # used_categories = category_mapping.values.uniq
      # all_categories = category_mapping.keys
      # unused_categories = all_categories - used_categories
      # @nodes_and_edges["nodes"].reject! do |node|
      #   node["type"].to_s.upcase == "CATEGORY" && unused_categories.include?(node["name"])
      # end

      # # Update remaining category node names
      # @nodes_and_edges["nodes"].each do |node|
      #   if node["type"].to_s.upcase == "CATEGORY" && category_mapping.key?(node["name"])
      #     node["name"] = category_mapping[node["name"]]
      #   end
      # end
      @nodes_and_edges["nodes"] = merged_nodes
    end

    def validate_nodes_with_llm
      prompt = Prompt.find_by(name: "kg_validation")
      replacement_hash = prompt.tags_hash.tap do |h|
        h[:nodes] = nodes_and_edges["nodes"].to_json
      end
      query = prompt.content % replacement_hash
      @node_mapping = Llm::QueryService.new(temperature: 0.4, model: @model).json_from_query(query)
    end
  end
end