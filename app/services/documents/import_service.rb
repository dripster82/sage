module Documents
  class ImportService

    def initialize(file_path)
      @file_path = file_path
      @chunks = nil
      @text = nil
    end

    def process
      read_file
      split_text
      embed_chunks
      build_knowledge_graph
    end

    private

    def build_knowledge_graph

      start_time = Time.now
      puts "Graphing Chunks(#{@chunks.size})"
      data = KnowledgeGraph::BuildService.new.build_from_chunks(@chunks)
      puts "Time to build knowledge graph: #{Time.now - start_time} seconds"
      
      data
    end

    def embed_chunks
      start_time = Time.now
      puts "Embedding Chunks(#{@chunks.size})"
      Llm::EmbeddingService.new.embed_chunks(@chunks)
      puts "Time to embed chunks: #{Time.now - start_time} seconds"
    end

    def split_text
      start_time = Time.now
      puts "Splitting text from #{@file_path}"
      
      @chunks = ChunkService.new(@file_path).chunk(@text)

      puts "Time to split text: #{Time.now - start_time} seconds"
    end

    def read_file
      start_time = Time.now
      puts "Reading file from #{@file_path}"
      source_type = File.extname(@file_path)
      content_type = MIME::Types.type_for(@file_path).first.content_type

      file_processor = processors.find { |klass|  
        FileProcessor.const_get(klass)::EXTENSIONS.include?(source_type) || 
        FileProcessor.const_get(klass)::CONTENT_TYPES.include?(content_type) 
      }
      file_data = File.open(@file_path)
      @text = FileProcessor.const_get(file_processor).parse(file_data)
      puts "Time to read file: #{Time.now - start_time} seconds"
    end

    def processors
      FileProcessor.constants
    end
  end
end