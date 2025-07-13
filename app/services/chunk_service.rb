require "baran"

class ChunkService
  
  def initialize(file, chunk_size: 1000, chunk_overlap: 100, separators: ["\n\n", "\n", " ", ""])
    @chunk_size = chunk_size
    @chunk_overlap = chunk_overlap
    @separators = separators
    @file_path = file
  end

  def chunk(text, size: 1000, overlap: 100)
    raise ArgumentError, "Size must be greater than overlap" if size <= overlap
  
    splitter = Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: @chunk_size,
      chunk_overlap: @chunk_overlap,
      separators: @separators
    )

    splitter.chunks(text).map.with_index do |chunk, position|
      Chunk.new(
        text: chunk[:text],
        file_path: @file_path,
        position: position
      )
    end
  end
end