module KnowledgeGraph
  class QueryService
    
    def query(cypher)
      results = ActiveGraph::Base.query(cypher)
      JSON.parse(results.to_json)
    end
  end
end