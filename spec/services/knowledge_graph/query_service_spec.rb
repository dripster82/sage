# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KnowledgeGraph::QueryService, type: :service do
  let(:service) { KnowledgeGraph::QueryService.new }

  it_behaves_like 'a service object'

  describe '#query' do
    let(:cypher_query) { 'MATCH (n) RETURN n LIMIT 10' }
    let(:mock_results) { [{ 'n' => { 'name' => 'Test Node' } }] }

    before do
      allow(ActiveGraph::Base).to receive(:query).and_return(mock_results)
    end

    it 'executes cypher query through ActiveGraph' do
      expect(ActiveGraph::Base).to receive(:query).with(cypher_query)
      service.query(cypher_query)
    end

    it 'returns JSON parsed results' do
      allow(mock_results).to receive(:to_json).and_return('[{"n":{"name":"Test Node"}}]')
      
      result = service.query(cypher_query)
      expect(result).to eq([{ 'n' => { 'name' => 'Test Node' } }])
    end

    it 'handles empty results' do
      allow(ActiveGraph::Base).to receive(:query).and_return([])
      
      result = service.query(cypher_query)
      expect(result).to eq([])
    end

    it 'handles complex query results' do
      complex_results = [
        { 'node' => { 'id' => 1, 'name' => 'Node 1', 'type' => 'Person' } },
        { 'node' => { 'id' => 2, 'name' => 'Node 2', 'type' => 'Company' } }
      ]
      allow(ActiveGraph::Base).to receive(:query).and_return(complex_results)
      
      result = service.query(cypher_query)
      expect(result).to eq(complex_results)
    end
  end

  describe 'cypher query types' do
    before do
      allow(ActiveGraph::Base).to receive(:query).and_return([])
    end

    it 'handles MATCH queries' do
      match_query = 'MATCH (n:Person) RETURN n.name'
      expect { service.query(match_query) }.not_to raise_error
    end

    it 'handles CREATE queries' do
      create_query = 'CREATE (n:Person {name: "John"}) RETURN n'
      expect { service.query(create_query) }.not_to raise_error
    end

    it 'handles MERGE queries' do
      merge_query = 'MERGE (n:Person {name: "John"}) RETURN n'
      expect { service.query(merge_query) }.not_to raise_error
    end

    it 'handles DELETE queries' do
      delete_query = 'MATCH (n:Person {name: "John"}) DELETE n'
      expect { service.query(delete_query) }.not_to raise_error
    end

    it 'handles complex relationship queries' do
      relationship_query = 'MATCH (a:Person)-[r:KNOWS]->(b:Person) RETURN a, r, b'
      expect { service.query(relationship_query) }.not_to raise_error
    end
  end

  describe 'error handling' do
    it 'handles ActiveGraph connection errors' do
      allow(ActiveGraph::Base).to receive(:query).and_raise(StandardError, 'Connection failed')

      result = service.query('INVALID QUERY')
      expect(result).to eq([])
    end

    it 'handles invalid cypher syntax' do
      allow(ActiveGraph::Base).to receive(:query).and_raise(StandardError, 'Invalid syntax')

      result = service.query('INVALID CYPHER')
      expect(result).to eq([])
    end

    it 'handles JSON parsing errors' do
      mock_results = double('Results')
      allow(ActiveGraph::Base).to receive(:query).and_return(mock_results)
      allow(mock_results).to receive(:to_json).and_raise(JSON::GeneratorError)

      result = service.query('MATCH (n) RETURN n')
      expect(result).to eq([])
    end

    it 'handles nil query input' do
      allow(ActiveGraph::Base).to receive(:query).with(nil).and_raise(StandardError, 'Nil query')

      result = service.query(nil)
      expect(result).to eq([])
    end

    it 'handles empty query string' do
      allow(ActiveGraph::Base).to receive(:query).with('').and_return([])
      
      result = service.query('')
      expect(result).to eq([])
    end
  end

  describe 'integration with ActiveGraph' do
    it 'uses ActiveGraph::Base.query method' do
      query = 'MATCH (n) RETURN count(n)'
      expect(ActiveGraph::Base).to receive(:query).with(query)
      service.query(query)
    end

    it 'properly formats results for JSON conversion' do
      mock_results = [{ 'count' => 5 }]
      allow(ActiveGraph::Base).to receive(:query).and_return(mock_results)
      
      # Ensure to_json is called on the results
      expect(mock_results).to receive(:to_json).and_return('[{"count":5}]')
      
      service.query('MATCH (n) RETURN count(n)')
    end
  end

  describe 'performance' do
    before do
      allow(ActiveGraph::Base).to receive(:query).and_return([])
    end

    it 'handles large result sets efficiently' do
      # Simulate large result set
      large_results = (1..1000).map { |i| { 'id' => i, 'name' => "Node #{i}" } }
      allow(ActiveGraph::Base).to receive(:query).and_return(large_results)
      
      expect {
        Timeout.timeout(5) do
          result = service.query('MATCH (n) RETURN n')
          expect(result.size).to eq(1000)
        end
      }.not_to raise_error
    end

    it 'handles complex queries efficiently' do
      complex_query = <<~CYPHER
        MATCH (a:Person)-[r1:KNOWS]->(b:Person)-[r2:WORKS_AT]->(c:Company)
        WHERE a.age > 25 AND c.industry = 'Technology'
        RETURN a.name, b.name, c.name, r1.since, r2.position
        ORDER BY a.name
        LIMIT 100
      CYPHER
      
      expect {
        Timeout.timeout(3) do
          service.query(complex_query)
        end
      }.not_to raise_error
    end
  end

  describe 'usage in knowledge graph operations' do
    before do
      mock_neo4j_query([])
    end

    it 'can be used for node creation' do
      create_query = 'CREATE (n:Document {title: "Test"}) RETURN n'
      expect { service.query(create_query) }.not_to raise_error
    end

    it 'can be used for relationship creation' do
      rel_query = 'MATCH (a:Document), (b:Person) CREATE (a)-[r:AUTHORED_BY]->(b) RETURN r'
      expect { service.query(rel_query) }.not_to raise_error
    end

    it 'can be used for data retrieval' do
      search_query = 'MATCH (n:Document) WHERE n.title CONTAINS "test" RETURN n'
      expect { service.query(search_query) }.not_to raise_error
    end
  end

  describe 'thread safety' do
    it 'handles concurrent queries safely' do
      queries = [
        'MATCH (n:Person) RETURN count(n)',
        'MATCH (n:Company) RETURN count(n)',
        'MATCH (n:Document) RETURN count(n)'
      ]
      
      allow(ActiveGraph::Base).to receive(:query).and_return([{ 'count' => 1 }])
      
      threads = queries.map do |query|
        Thread.new { service.query(query) }
      end
      
      expect { threads.each(&:join) }.not_to raise_error
    end
  end

  describe 'memory management' do
    it 'does not leak memory with repeated queries' do
      allow(ActiveGraph::Base).to receive(:query).and_return([{ 'result' => 'data' }])
      
      initial_memory = GC.stat[:total_allocated_objects]
      
      100.times do
        service.query('MATCH (n) RETURN n LIMIT 1')
      end
      
      GC.start
      final_memory = GC.stat[:total_allocated_objects]
      
      # Memory should not grow excessively
      expect(final_memory - initial_memory).to be < 1000000
    end
  end
end
