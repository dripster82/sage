require "pdf-reader"

module FileProcessor
  class Pdf
      EXTENSIONS = [".pdf"]
      CONTENT_TYPES = ["application/pdf"]

      # Parse the document and return the text
      # @param [File] data
      # @return [String]
      def self.parse(data)
        ::PDF::Reader
          .new(StringIO.new(data.read))
          .pages
          .map(&:text)
          .join("\n\n")
      end
  end
end