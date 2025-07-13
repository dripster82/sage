class Chunk
  include ActiveModel::Model

  attr_accessor :text, :file_path, :position, :vector
end