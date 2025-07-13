module KnowledgeGraph
  class BuildService

    def initialize(chunks)
      @chunks = chunks
      @nodes_and_edges = []
      @current_doc_schema = {
        node_types: ["Document", "Statement", "Code", "Project", "Person", "Job Title", "Company", "Coding Pattern", "Platform", "Category"], 
        edge_types: ["mentioned_in", "used_in", "belongs_to", "works_at", "works_on", "is_a", "discusses"]
      }
    end

    def process
      process_with_llm 
      save_chunk_nodes_and_edges 
    end

    def save_chunk_nodes_and_edges
      kg_service = KnowledgeGraph::QueryService.new
      @nodes_and_edges.each do |node_and_edge|
        node_and_edge[:nodes].each do |node|
          attribute_string = node[:attributes].map { |key, value| "#{key}: '#{value}'" }.join(", ")
          cypher = "CREATE (n:#{node[:type]} { name: '#{node[:name]}', #{attribute_string} })"
          kg_service.query(cypher)
        end          sleep_time = interval - (now - last_time)
      end
    end

    def process_with_llm(@chunks)
      raise ArgumentError, "Chunks must be an array of Chunk instances" unless @chunks.is_a?(Array) && chunks.all? { |c| c.is_a?(Chunk) }
      
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
      nil
    end

    private

    def extract_nodes_and_edges(chunk)
      # Use LLM to process the chunk text and get KnowledgeGraph nodes and edges
      
      prompt = <<~PROMPT
Extract knowledge graph nodes and edges from the following text: 
<TEXT START>
#{sanitized_text(chunk.text)}
<TEXT END>

Current schema: #{@current_doc_schema.to_json}

When using statements, linking to other nodes should be
Node - mentioned_in -> Statment
Statement - discusses -> Node

INSTRUCTIONS:
- Review the text and generate a list with all the key information that should be nodes.
- Review the text and the node list and generate a list of relationships between those nodes
- If the current Node Types are not suitable for the new node info, then you can suggest a new node type to use that describes the new node info type - Try to not be too generic,
- If the edge Types do not work for the relationships needed to express the content of the text then new edges can be suggested
- look at each node and suggest new category nodes it could be grouped/linked with 
eg 
1) Harry Potter and the Goblet of Fire - Category would be Book so we would add a new node "Book" of type "Category" and link Harry Potter and the Goblet of Fire to the Book node with "is_a" or "belongs_to" 
2) Ruby on Rails - Category would be Programming Framework so we would add a new node "Programming Framework" of type "Category" and link the Ruby on Rails node to the Programming Framework with "is_a" or "belongs_to"
      PROMPT

      response = RubyLLM.chat.ask(prompt).content

      prompt2 = <<~PROMPT2
SOURCE TEXT:
#{sanitized_text(chunk.text)}
RESPONSE:
#{response}
OUTPUT FORMAT:
{
"Nodes": [
{"name": "NodeName", "type": "NodeType", "attributes": {"key": "value"}},
{"name": "Tron", "type": "Movie", "attributes": {"released": "1982"}},
{"name": "Film", "type": "Category", "attributes": {}},
{"name": "Jeff", "type": "Person", "attributes": {"born": "1962/02/02"}},
{"name": "Actor", "type": "Category", "attributes": {}},
...
],
"Edges": [
{"source": "Tron", "target": "Film", "type": "is_a", "attributes": {}},
{"source": "Jeff", "target": "Tron", "type": "was_in", "attributes": {}},
{"source": "Jeff", "target": "Actor", "type": "is_a", "attributes": {}},
...
],
new_schema: {
"node_types": ["NodeType1", "NodeType2", "Movie", ...],
"edge_types": ["EdgeType1", "EdgeType2", "was_in, ...]
}
}

INSTRUCTIONS:
Generate a json output of the nodes and edges for this text
Ensure the output is a valid JSON object.
Only return the JSON object, do not include any additional text or explanations or markdown formatting
      PROMPT2


      node_data = RubyLLM.chat.ask(prompt2).content
      # puts node_data
# strip_formatting(node_data)
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