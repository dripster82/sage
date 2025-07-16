module Documents
  class ImportService

    attr_accessor :document
    def initialize(file_path)
      @document = Document.new(file_path: file_path)
    end

    def process
      Current.ailog_session = SecureRandom.uuid 
      read_file
      summerise_doc
      split_text
      embed_chunks
      build_knowledge_graph
      Current.ailog_session = nil
    end

    

    def summerise_doc
      start_time = Time.now
      puts "Summarising document"
      prompt = Prompt.find_by(name: "text_summarization")
      replacement_hash = prompt.tags_hash.tap do |h|
        h[:text] = @document.text
      end
      prompt_query = prompt.content % replacement_hash
      @document.summary = Llm::QueryService.new.ask(prompt_query).content
      @document.vector = Llm::EmbeddingService.new.embed_text(@document.summary).vectors
      
      puts "---"
      puts @document.summary
      puts "---"
      puts "Time to summarise document: #{Time.now - start_time} seconds"
    end

    def build_knowledge_graph

      start_time = Time.now
      puts "Graphing Chunks(#{@document.chunks.size})"
      data = KnowledgeGraph::BuildService.new(@document).process
      puts "Time to build knowledge graph: #{Time.now - start_time} seconds"
      
      data
    end

    def embed_chunks
      start_time = Time.now
      puts "Embedding Chunks(#{@document.chunks.size})"
      Llm::EmbeddingService.new.embed_chunks(@document.chunks)
      puts "Time to embed chunks: #{Time.now - start_time} seconds"
    end

    def split_text
      start_time = Time.now
      puts "Splitting text from #{@document.file_path}"
      
      ChunkService.new(@document).chunk

      puts "Time to split text: #{Time.now - start_time} seconds"
    end

    def read_file
      start_time = Time.now
      puts "Reading file from #{@document.file_path}"

      file_processor = processors.find { |klass|  
        FileProcessor.const_get(klass)::EXTENSIONS.include?(@document.source_type) || 
        FileProcessor.const_get(klass)::CONTENT_TYPES.include?(@document.content_type) 
      }
      file_data = File.open(@document.file_path)
      @document.text = FileProcessor.const_get(file_processor).parse(file_data)
      puts "Time to read file: #{Time.now - start_time} seconds"
    end

    def processors
      FileProcessor.constants
    end
  end
end