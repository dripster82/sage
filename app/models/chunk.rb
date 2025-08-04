class Chunk
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :text, :string
  attribute :file_path, :string
  attribute :position, :integer
  attribute :vector
end