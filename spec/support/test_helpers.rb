# frozen_string_literal: true

module TestHelpers
  # Helper methods for authentication in tests
  module AuthenticationHelpers
    def sign_in_admin_user(admin_user = nil)
      admin_user ||= create(:admin_user)
      sign_in admin_user
      admin_user
    end

    def sign_out_admin_user
      sign_out :admin_user
    end
  end

  # Helper methods for mocking external services
  module MockHelpers
    def mock_llm_response(content: 'Mocked LLM response', tokens: { input: 100, output: 50 })
      response_double = double('LLM Response',
        content: content,
        input_tokens: tokens[:input],
        output_tokens: tokens[:output]
      )

      allow_any_instance_of(Llm::QueryService).to receive(:ask).and_return(response_double)
      # Mock json_from_query to return valid JSON data
      # For node validation, it expects an array of mappings
      allow_any_instance_of(Llm::QueryService).to receive(:json_from_query).and_return([])
      response_double
    end

    def mock_embedding_response(vectors: Array.new(1536) { rand })
      embedding_double = double('Embedding Response', vectors: vectors)
      allow_any_instance_of(Llm::EmbeddingService).to receive(:embed_text).and_return(embedding_double)
      allow_any_instance_of(Llm::EmbeddingService).to receive(:embed_chunks).and_return(nil)
      embedding_double
    end

    def mock_neo4j_query(result = [])
      allow(ActiveGraph::Base).to receive(:query).and_return(result)
      # Mock KnowledgeGraph::QueryService
      allow_any_instance_of(KnowledgeGraph::QueryService).to receive(:query).and_return(result)
      # Mock File.write for cypher files
      allow(File).to receive(:write).and_return(true)
    end

    def mock_file_processor(content = 'Mocked file content')
      # Mock File.open to return a StringIO with the content
      allow(File).to receive(:open).and_return(StringIO.new(content))

      # Mock the file processors (these are class methods, not instance methods)
      allow(FileProcessor::Txt).to receive(:parse).and_return(content)
      allow(FileProcessor::Pdf).to receive(:parse).and_return(content)

      # Mock MIME type detection
      allow(MIME::Types).to receive(:type_for).and_return([double(content_type: 'text/plain')])
    end
  end

  # Helper methods for creating test data
  module DataHelpers
    def create_test_document(file_path: 'test.txt', text: 'Test document content', chunks: nil)
      Document.new(
        file_path: file_path,
        text: text,
        summary: 'Test summary',
        vector: Array.new(1536) { rand },
        chunks: chunks || create_test_chunks(3)
      )
    end

    def create_test_chunks(count = 3)
      (1..count).map do |i|
        Chunk.new(
          text: "Test chunk #{i} content",
          file_path: 'test.txt',
          position: i - 1,
          vector: Array.new(1536) { rand }
        )
      end
    end

    def create_test_prompt(name: 'test_prompt', content: 'Test prompt content with %{text}')
      admin_user = create(:admin_user)
      create(:prompt,
        name: name,
        content: content,
        created_by: admin_user,
        updated_by: admin_user
      )
    end
  end

  # Helper methods for time manipulation in tests
  module TimeHelpers
    def travel_to_time(time)
      travel_to(time) { yield }
    end

    def freeze_time_helper
      freeze_time { yield }
    end
  end

  # Helper methods for file operations in tests
  module FileHelpers
    def create_temp_file(content: 'Test file content', extension: '.txt')
      file = Tempfile.new(['test', extension])
      file.write(content)
      file.rewind
      file
    end

    def create_temp_pdf
      # This would require a PDF generation library in a real implementation
      # For now, we'll create a simple text file with PDF extension
      create_temp_file(content: 'PDF content', extension: '.pdf')
    end
  end
end

# Include helpers in RSpec configuration
RSpec.configure do |config|
  config.include TestHelpers::AuthenticationHelpers, type: :controller
  config.include TestHelpers::AuthenticationHelpers, type: :request
  config.include TestHelpers::MockHelpers
  config.include TestHelpers::DataHelpers
  config.include TestHelpers::TimeHelpers
  config.include TestHelpers::FileHelpers
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
end
