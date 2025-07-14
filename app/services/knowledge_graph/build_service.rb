module KnowledgeGraph
  class BuildService

    def initialize(chunks, document)
      @chunks = chunks
      @document = document
      @nodes_and_edges = []
      @current_doc_schema = {
        node_types: ["Document", "Statement", "Code", "Project", "Person", "Job Title", "Company", "Coding Pattern", "Platform", "Category", "Entity"], 
        edge_types: ["mentioned_in", "used_in", "belongs_to", "works_at", "works_on", "is_a", "discusses"],
        catgegories: ["Code", "Source Document", "Ai", "HR", "Customers"]
      }

      @prompt1 = Prompt.find_by(name: "kg_extraction_1st_pass")
      @prompt2 = Prompt.find_by(name: "kg_extraction_2nd_pass")
      @category_validation_prompt = Prompt.find_by(name: "kg_extraction_category_validation")
    end

    def process
      process_with_llm 
      preprocess_nodes_and_edges
      validate_node_categories
      save_chunk_nodes_and_edges 
    end

    def validate_node_categories

      categories = @nodes_and_edges["nodes"].map do |node|
        node if node["type"].upcase == "CATEGORY"
      end.compact

      return if categories.empty?


      # Use LLM to validate the categories of the nodes
      replacement_hash = @category_validation_prompt.tags_hash.tap do |h|
        h[:categories] = categories.map { |c| c["name"] }.join(", ")
        h[:summary] = @document.summary
      end
      query = @category_validation_prompt.content % replacement_hash
      response =  Llm::QueryService.new(temperature:0.4).ask(query).content

      puts response
      raise "STOPPING"

    end

    def preprocess_nodes_and_edges
      #remove duplicate nodes and edges form the combined node_and_edge
      merged_nodes_and_edges = {}
      @nodes_and_edges.each do |chunk|
        chunk.each do |key, value|
          merged_nodes_and_edges[key] ||= []
          if value.is_a?(Array)
            value.each do |item|
              if key == 'nodes'
                existing_node = merged_nodes_and_edges[key].find { |node| node['name'] == item['name'] && node['node_type'] == item['node_type'] }
                if existing_node && item.has_key?("attributes") && item["attributes"].any?
                  # Merge attributes from the duplicate node
                  existing_node["attributes"] ||= {}
                  existing_node["attributes"].merge!(item["attributes"]) { |_, old_val, new_val| Array(old_val) + Array(new_val) }
                else
                  merged_nodes_and_edges[key] << item
                end
              elsif key == 'edges'
                existing_edge = merged_nodes_and_edges[key].find { |edge| edge['source'] == item['source'] && edge['target'] == item['target'] && edge['type'] == item['type'] }
                if existing_edge && item.has_key?("attributes") && item["attributes"].any?
                  # Merge attributes from the duplicate edge
                  existing_edge["attributes"] ||= {}
                  existing_edge["attributes"].merge!(item["attributes"]) { |_, old_val, new_val| Array(old_val) + Array(new_val) }
                else
                  merged_nodes_and_edges[key] << item
                end
              end
            end
            # merged_nodes_and_edges[key] = merged_nodes_and_edges[key] + value
          elsif value.is_a?(Hash)
            merged_nodes_and_edges[key] << value
          end
        end
      end

      @nodes_and_edges = merged_nodes_and_edges
    end


    def save_chunk_nodes_and_edges
      save_nodes
      save_edges
    end

    def save_edges 
      
      kg_service = KnowledgeGraph::QueryService.new
      edge_template = <<~TEMPLATE
          MATCH (source:%{source_type} { name: "%{source_name}" })
          MATCH (target:%{target_type} { name: "%{target_name}" })
          MERGE (source)-[r:%{type}]->(target)%{attributes_clause}
        TEMPLATE
        attributes_clause = <<~TEMPLATE

          ON CREATE SET %{attributes}
          ON MATCH SET %{attributes}
      TEMPLATE
      
      @nodes_and_edges["edges"].each do |edge|
        attribute_pattern = nil
        if edge.has_key?("attributes") && edge["attributes"].any?
          attributes = edge["attributes"].map do |key, value| 
            val = value.is_a?(String) ? value.gsub('"', '\"') : value
            "r.#{key.downcase} = \"#{val}\"" 
          end.join(", ")
          attribute_pattern = attributes_clause % { attributes: attributes }
        end
        cypher = edge_template % { 
          source_type: edge["source_type"].upcase, 
          source_name: edge["source"].gsub('"', '\"'), 
          target_type: edge["target_type"].upcase, 
          target_name: edge["target"].gsub('"', '\"'), 
          type: edge["type"].upcase, 
          attributes_clause: attribute_pattern 
        }
        cypher = cypher.strip + ";"
        # kg_service.query(cypher)
        puts cypher
      end
    end

    def save_nodes
      kg_service = KnowledgeGraph::QueryService.new
      node_template = <<~TEMPLATE
          MERGE (n:%{type} { name: "%{name}" })%{attributes_clause}
        TEMPLATE
      attributes_clause = <<~TEMPLATE

          ON CREATE SET %{attributes}
          ON MATCH SET %{attributes}
      TEMPLATE

      @nodes_and_edges["nodes"].each do |node|
        attribute_pattern = nil

        if node.has_key?("attributes") && node["attributes"].any?
          attributes = node["attributes"].map do |key, value| 
            val = value.is_a?(String) ? value.gsub('"', '\"') : value
            "n.#{key.downcase} = \"#{val}\"" 
          end.join(", ")
          attribute_pattern = attributes_clause % { attributes: attributes }
        end
        cypher = node_template % { type: node["type"].upcase, name: node["name"].gsub('"', '\"'), attributes_clause: attribute_pattern }
        cypher = cypher.strip + ";"
        # kg_service.query(cypher)
        puts cypher
      end 
    end

    def process_with_llm
      raise ArgumentError, "Chunks must be an array of Chunk instances" unless @chunks.is_a?(Array) && @chunks.all? { |c| c.is_a?(Chunk) }
      
      total_start_time = Time.now
      
      max_threads =  ENV.fetch('EXTRACTING_NODE_THREADS', 5).to_i
      max_per_minute = ENV.fetch('EXTRACTING_NODE_RPM', 500).to_i
      interval = 60.0 / max_per_minute
      semaphore = SizedQueue.new(max_threads)
      last_call_time = Mutex.new
      last_time = Time.at(0)
      @nodes_and_edges =[]
      threads = @chunks.map.with_index do |chunk, index|
        Thread.new do
          semaphore.push(true)  # acquire slot
          begin
            last_call_time.synchronize do
              now = Time.now
              elapsed = now - last_time
              if elapsed < interval
                sleep(interval - elapsed)
              end
              last_time = Time.now
            end
            data = extract_nodes_and_edges(chunk)
            @nodes_and_edges[index] = data
          ensure
            semaphore.pop
          end
        end
      end

      threads.each(&:join)

      puts "Total time to build knowledge graph from chunks: #{Time.now - total_start_time} seconds"

      @nodes_and_edges
    rescue StandardError => e
      Rails.logger.error("Failed to build knowledge graph from chunks: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      nil
    end

    private

    def extract_nodes_and_edges(chunk)
      # Use LLM to process the chunk text and get KnowledgeGraph nodes and edges
      

      # create a replacement hash where the hash uses the tagslist as the keys and nil as the values
      replacement_hash = @prompt1.tags_hash.tap do |h|
        h[:text] = sanitized_text(chunk.text)
        h[:current_schema] = @current_doc_schema.to_json
        h[:summary] = @document.summary
      end
      prompt1_query = @prompt1.content % replacement_hash
      response =  Llm::QueryService.new(temperature:0.4).ask(prompt1_query).content


      replacement_hash = @prompt2.tags_hash.tap do |h|
        h[:text] = sanitized_text(chunk.text)
        h[:response] = response
        h[:current_schema] = @current_doc_schema.to_json
      end
      prompt2_query = @prompt2.content % replacement_hash
      node_data =  Llm::QueryService.new(temperature:0.4).ask(prompt2_query).content

      JSON.parse(strip_formatting(node_data))
    rescue JSON::ParserError => e
      puts "Failed to parse JSON: #{e.message}"
      puts "Raw response: #{node_data}"
      return { "Nodes" => [], "Edges" => [], "new_schema" => { "node_types" => [], "edge_types" => [] } }
    rescue => e
      puts "Error processing LLM response: #{e.message}"
      puts e.backtrace.join("\n")
      return { "Nodes" => [], "Edges" => [], "new_schema" => { "node_types" => [], "edge_types" => [] } }
    end


    def strip_formatting(str)
      str_array = str.split("\n")
      return str_array[1..-2].join("\n") if str_array.first.include?("```")

      str
    end

    def sanitized_text(text)
      text
    end
  end
end