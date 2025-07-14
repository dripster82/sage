# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
AdminUser.create_with(password: "password", password_confirmation: "password").find_or_create_by!(email: AdminUser::DEFAULT_EMAIL)

# Create sample prompts
admin_user = AdminUser.find_by(email: AdminUser::DEFAULT_EMAIL)

if admin_user && Prompt.count == 0
  puts "Creating sample prompts..."

  # Knowledge Graph Extraction Prompt
  kg_prompt = Prompt.create!(
    name: "knowledge_graph_extraction",
    description: "Prompt for extracting knowledge graph nodes and edges from text chunks",
    category: "knowledge_graph",
    status: "active",
    content: <<~PROMPT,
      Extract knowledge graph nodes and edges from the following text:
      <TEXT START>
      {{text}}
      <TEXT END>

      Current schema: {{schema}}

      When using statements, linking to other nodes should be:
      Node - mentioned_in -> Statement
      Statement - discusses -> Node

      Return the result as JSON with the following structure:
      {
        "nodes": [
          {
            "type": "NodeType",
            "name": "Node Name",
            "attributes": {
              "key": "value"
            }
          }
        ],
        "edges": [
          {
            "from": "Source Node",
            "to": "Target Node",
            "type": "relationship_type"
          }
        ]
      }
    PROMPT
    created_by: admin_user,
    updated_by: admin_user
  )

  # Text Summarization Prompt
  summary_prompt = Prompt.create!(
    name: "text_summarization",
    description: "Prompt for generating concise summaries of text content",
    category: "summarization",
    status: "active",
    content: <<~PROMPT,
      Please provide a concise summary of the following text:

      {{text}}

      Requirements:
      - Keep the summary under 200 words
      - Focus on key points and main ideas
      - Maintain the original tone and context
      - Use clear and professional language
    PROMPT
    created_by: admin_user,
    updated_by: admin_user
  )

  # Code Review Prompt
  code_review_prompt = Prompt.create!(
    name: "code_review_assistant",
    description: "Prompt for conducting thorough code reviews",
    category: "code_analysis",
    status: "draft",
    content: <<~PROMPT,
      Review the following code and provide feedback:

      ```{{language}}
      {{code}}
      ```

      Please analyze:
      1. Code quality and best practices
      2. Potential bugs or issues
      3. Performance considerations
      4. Security concerns
      5. Suggestions for improvement

      Provide specific, actionable feedback with examples where appropriate.
    PROMPT
    created_by: admin_user,
    updated_by: admin_user
  )

  puts "Created #{Prompt.count} sample prompts"
end
