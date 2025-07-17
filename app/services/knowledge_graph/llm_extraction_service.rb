module KnowledgeGraph
  class LlmExtractionService
    include DebuggableService
    
    def initialize(document)
      @current_doc_schema = {
        node_types: %w[ORGANIZATION,PERSON,STATEMENT,PLATFORM,MEDIA_OUTLET,CODE,TECHNOLOGY,COMPANY,PROJECT], 
        edge_types: ["mentioned_in", "used_in", "belongs_to", "works_at", "works_on", "is_a", "discusses"],
        catgegories: ["Code", "Source Document", "Ai", "HR", "Customers"]
      }
      @node_types = @current_doc_schema[:node_types]
      @document = document
      @chunks = document.chunks
      @nodes_and_edges = []
      
      @prompt1 = Prompt.find_by(name: "kg_extraction_1st_pass")
      @prompt2 = Prompt.find_by(name: "kg_extraction_2nd_pass")
    end

    def process
      extract_nodes_and_edges_from_chunks
      
      File.write("chunk_node.txt", JSON.pretty_generate(@nodes_and_edges))
      preprocess_nodes_and_edges
    end

    # private

    def extract_nodes_and_edges_from_chunks
      total_start_time = Time.now
      @nodes_and_edges = []
      max_threads =  ENV.fetch('EXTRACTING_NODE_THREADS', 5).to_i
      max_per_minute = ENV.fetch('EXTRACTING_NODE_RPM', 500).to_i
      interval = 60.0 / max_per_minute
      semaphore = SizedQueue.new(max_threads)
      last_call_time = Mutex.new
      last_time = Time.at(0)

      threads = @chunks.map.with_index do |chunk, index|
        ailog_session = Current.ailog_session
        Thread.new do
          Current.ailog_session = ailog_session
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
            Current.ailog_session = nil
          end
        end
      end

      threads.each(&:join)

      debug_log "Total time to build knowledge graph from chunks: #{Time.now - total_start_time} seconds"
    end


    def sanitized_text(text)
      text
    end

    def extract_nodes_and_edges(chunk)
      # create a replacement hash where the hash uses the tagslist as the keys and nil as the values
      replacement_hash = @prompt1.tags_hash.tap do |h|
        h[:text] = sanitized_text(chunk.text)
        h[:current_schema] = @node_types.join()
        h[:summary] = @document.summary
      end
      prompt1_query = @prompt1.content % replacement_hash
      response =  Llm::QueryService.new(temperature:0.4).ask(prompt1_query).content


      replacement_hash = @prompt2.tags_hash.tap do |h|
        h[:text] = sanitized_text(chunk.text)
        h[:summary] = @document.summary
        h[:response] = response
        h[:entity_types] = @current_doc_schema.to_json
      end
      prompt2_query = @prompt2.content % replacement_hash
      Llm::QueryService.new.json_from_query(prompt2_query)

    rescue JSON::ParserError => e
      debug_log "Failed to parse JSON: #{e.message}"
      debug_log "Raw response: #{node_data}"
      return { "Nodes" => [], "Edges" => [], "new_schema" => { "node_types" => [], "edge_types" => [] } }
    rescue => e
      debug_log "Error processing LLM response: #{e.message}"
      debug_log e.backtrace.join("\n")
      return { "Nodes" => [], "Edges" => [], "new_schema" => { "node_types" => [], "edge_types" => [] } }
    end


    def preprocess_nodes_and_edges
      #remove duplicate nodes and edges from the combined node_and_edge
      merged_nodes_and_edges = {}
      @nodes_and_edges.each do |chunk|
        chunk.each do |key, value|
          merged_nodes_and_edges[key] ||= []
          if value.is_a?(Array)
            value.each do |item|
              if key == 'nodes'
                item['type'] = item['type'].gsub(/\W/,"_").upcase
                item['name'] = item['name'].titleize
                existing_node["attributes"]["soft_types"].gsub(/\W/,"_").upcase if item.dig("attributes","soft_types")
                existing_node = merged_nodes_and_edges[key].find { |node| node['name'] == item['name'] && node['type'] == item['type'] }
                if existing_node && item.has_key?("attributes") && item["attributes"].any?
                  # Merge attributes from the duplicate node
                  existing_node["attributes"] ||= {}
                  existing_node["attributes"].merge!(item["attributes"]) { |_, old_val, new_val| new_val || old_val }
                  if existing_node.dig("attributes","soft_types") && existing_node["attributes"]["soft_types"].is_a?(Array)
                    existing_node["attributes"]["soft_types"] == existing_node["attributes"]["soft_types"].last
                  end
                elsif !existing_node
                  merged_nodes_and_edges[key] << item
                end
              elsif key == 'edges'
                %w[target_type source_type type].each do |k|
                  item[k] = item[k].gsub(/\W/,"_").upcase if item.has_key?(k)
                end
                %w[target source].each do |k|
                  item[k] = item[k].titleize if item.has_key?(k)
                end
                existing_edge = merged_nodes_and_edges[key].find { |edge|
                  %w[source target target_type source_type type].all? do |k|
                    edge[k] == item[k]
                  end 
                }
                if existing_edge && item.has_key?("attributes") && item["attributes"].any?
                  # Merge attributes from the duplicate edge
                  existing_edge["attributes"] ||= {}
                  existing_edge["attributes"].merge!(item["attributes"]) { |_, old_val, new_val| new_val || old_val}
                elsif !existing_edge
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

      merged_nodes_and_edges
    end
  end
end