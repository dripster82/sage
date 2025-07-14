class Document
  include ActiveModel::Model

  attr_accessor :text, :file_path, :summary, :vector


  def source_type
      File.extname(file_path)
  end

  def content_type
    MIME::Types.type_for(file_path).first.content_type
  end

end