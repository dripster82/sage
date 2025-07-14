require "baran"

class ChunkService
  
  def initialize(document, chunk_size: 1000, chunk_overlap: 100, separators: ["\n\n", "\n", " ", ""])
    @chunk_size = chunk_size
    @chunk_overlap = chunk_overlap
    @separators = separators
    @document = document
  end

  def chunk(text = @document.text, size: 1000, overlap: 100)
    raise ArgumentError, "Size must be greater than overlap" if size <= overlap
  
    splitter = Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: @chunk_size,
      chunk_overlap: @chunk_overlap,
      separators: @separators
    )

    splitter.chunks(text).map.with_index do |chunk, position|
      Chunk.new(
        text: chunk[:text],
        file_path: @document.file_path,
        position: position
      )
    end
  end
end