module KnowledgeGraph
  class QueryService
    def initialize(cypher_query = nil)
      @cypher_query = cypher_query
    end

    def call
      return [] unless @cypher_query
      query(@cypher_query)
    end

    def query(cypher)
      results = ActiveGraph::Base.query(cypher)
      JSON.parse(results.to_json)
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing error in QueryService: #{e.message}"
      []
    rescue => e
      Rails.logger.error "Query error in QueryService: #{e.message}"
      []
    end
  end
end