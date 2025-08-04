require "baran"

class ChunkService

  def initialize(document, chunk_size: 1000, chunk_overlap: 100, separators: ["\n\n", "\n", " ", ""])
    @chunk_size = chunk_size
    @chunk_overlap = chunk_overlap
    @separators = separators
    @document = document
  end

  # Service object interface
  def call(text = nil)
    chunk(text)
  end

  def chunk(text = @document.text, size: nil, overlap: nil, seperators: nil)
    # Use defaults if not provided
    actual_size = size || @chunk_size
    actual_overlap = overlap || @chunk_overlap

    raise ArgumentError, "Size must be greater than overlap" if actual_size <= actual_overlap

    # Handle nil or empty text
    if text.nil? || text.empty?
      @document.chunks = []
      return
    end

    splitter = Baran::RecursiveCharacterTextSplitter.new(
      chunk_size: actual_size,
      chunk_overlap: actual_overlap,
      separators: seperators || @separators
    )

    @document.chunks = splitter.chunks(text).map.with_index do |chunk, position|
      Chunk.new(
        text: chunk[:text],
        file_path: @document.file_path,
        position: position
      )
    end
  end
end