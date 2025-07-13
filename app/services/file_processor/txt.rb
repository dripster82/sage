
module FileProcessor
  class Txt
    EXTENSIONS = [".txt"]
    CONTENT_TYPES = ["text/plain"]

    # Parse the document and return the text
    # @param [File] data
    # @return [String]
    def self.parse(data)
      data.read
    end
  end
end