class Document
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :text, :string
  attribute :file_path, :string
  attribute :summary, :string
  attribute :vector
  attribute :chunks


  def source_type
      File.extname(file_path)
  end

  def content_type
    MIME::Types.type_for(file_path).first.content_type
  end

end