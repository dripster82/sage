# TODO List

## Knowledge Graph (KG) Work Completion
Complete the remaining knowledge graph implementation and management features to enable full KG functionality.

- [x] **Category Cleaning and De-duplication**
  Implement automated and manual processes to clean up duplicate categories and standardize category naming conventions. Current implementation in `KnowledgeGraph::BuildService` has validation code but it's incomplete (stops with `raise "STOPPING"`).

- [x] **Node and Edge Insertion to KG**
  Complete the core functionality to insert new nodes and edges into the knowledge graph database. Current implementation in `KnowledgeGraph::BuildService` has the code but it's commented out (lines with `# kg_service.query(cypher)`).

- [x] **Validate Nodes with LLM**
  Implement a service to validate and clean up extracted nodes using an LLM. Current implementation in `KnowledgeGraph::LlmValidationService` is a start but needs more work.

- [ ] **New Category Approval Table**
  Create an administrative interface to review and approve newly created categories before they are integrated into the main knowledge graph. This requires:
  - New database model for category approval
  - ActiveAdmin interface for category management
  - Workflow for category approval/rejection

- [ ] **Node Types Management Table**
  Develop a system to manage soft-types and allow administrators to promote frequently used soft-types to official node types. This requires:
  - New database model for node type management
  - ActiveAdmin interface for node type promotion
  - Integration with KG schema

- [ ] **Category and Node Type Promotion Service**
  Build a service layer to handle the promotion of soft-types to node types and removal of obsolete categories with proper data migration.

- [ ] **In-Memory KG Schema Storage**
  Implement caching mechanism to store the knowledge graph schema in memory for quick retrieval and improved performance. Current schema is hardcoded in `KnowledgeGraph::BuildService`.

## Document Management System
Integrate document storage and management capabilities with the knowledge graph system.

- [ ] **Document Model Integration**
  Create a persistent document model in the SQL database that links documents to their corresponding knowledge graph entities via KG IDs. Current `Document` class is only an ActiveModel without database persistence.

- [ ] **Document Upload and URL Import**
  Build user interface and backend functionality to allow users to upload documents or provide URLs for automatic document import. This requires:
  - File upload controller and form
  - URL fetching service
  - Integration with document processing pipeline

- [ ] **Background Job Processing**
  Implement asynchronous job processing system to handle document import operations without blocking the user interface. This requires:
  - Background job for document processing
  - Job status tracking
  - Error handling and retry logic

- [ ] **Document Query Interface**
  Create an intuitive interface that allows users to search and query the imported documentation effectively.

## Search and Discovery Services
Develop comprehensive search capabilities that leverage both document content and knowledge graph relationships.

- [ ] **Search Service Implementation**
  Build a robust search service that combines multiple search strategies for comprehensive results. This requires:
  - Search controller and API endpoints
  - Integration with KG query service
  - Search results formatting and pagination

- [ ] **Similarity Search on KG Chunks and Documents**
  Implement vector-based similarity search across knowledge graph chunks and document content for semantic matching. Current embedding service exists but needs integration with search functionality.

- [ ] **Two-Hop Node Retrieval**
  Develop functionality to retrieve nodes that are two degrees of separation away from search results to provide broader context.

- [ ] **Document Summary Integration**
  Include relevant document summaries in search results to provide quick context and relevance indicators.

## Data Management and Cleanup
Ensure proper data lifecycle management and system maintenance capabilities.

- [ ] **Cascading Document Deletion**
  Implement proper cleanup logic so that deleting documents automatically removes associated nodes and edges that aren't linked to other documents. This requires:
  - Document deletion service
  - KG cleanup logic
  - Orphaned node detection

- [ ] **Dashboard Metrics Update**
  Enhance the system dashboard to display the total number of documents in the system and other relevant metrics. Current dashboard only shows cost metrics.

## Node Enhancement
Improve the descriptiveness and usability of knowledge graph nodes.

- [ ] **Expanded Node Descriptions**
  Enhance node data structures to include more comprehensive and descriptive information for better user understanding and system utility.

## Additional Required Tasks

- [ ] **RSpec Testing Suite Setup**
  Set up RSpec testing framework to replace current test suite:
  - Install and configure RSpec gems
  - Set up test database configuration
  - Create factory_bot for test data generation
  - Configure test helpers and shared examples
  - Set up test coverage reporting

- [ ] **Generic Node and Edge Models (Optional)**
  Create generic ActiveRecord models for better KG service processing:
  - Generic Node model for KG query optimization
  - Generic Edge model for relationship management
  - These would be simple wrappers around the dynamic KG data, not predefined schemas

- [ ] **ActiveAdmin Interfaces**
  Create admin interfaces for managing documents and KG oversight:
  - Document admin interface for uploaded documents
  - KG overview interface for browsing nodes/edges
  - Category approval interface for new categories
  - Node type management interface

- [ ] **API Development**
  Create RESTful API endpoints for interacting with the knowledge graph:
  - Document upload/management API
  - Search API for querying documents and KG
  - KG query API for direct graph queries

- [ ] **Testing Infrastructure**
  Develop comprehensive RSpec test suite for all functionality:
  - Unit tests for services (LLM, KG, Document processing)
  - Integration tests for document import pipeline
  - System tests for admin interfaces
  - Mock LLM responses for consistent testing

- [ ] **Error Handling and Logging**
  Implement robust error handling and logging for KG operations:
  - Structured logging for KG operations
  - Error tracking and reporting
  - Monitoring dashboards for document processing status