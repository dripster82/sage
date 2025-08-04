# Reorganized TODO List

## 1. Core Infrastructure
Foundational systems and interfaces required for the application.

### Database and Models
- [ ] **Document Model Integration**
  Create persistent document model in SQL database that links documents to KG entities via KG IDs. Current `Document` class is only an ActiveModel without database persistence.

- [ ] **Category Approval Model**
  Create database model and workflow for reviewing/approving newly created categories before KG integration.

- [ ] **Node Type Management Model**
  Create database model for managing soft-types and promoting frequently used soft-types to official node types.

- [ ] **Generic Node and Edge Models (Optional)**
  Create simple ActiveRecord wrappers around dynamic KG data for better service processing optimization.

### Administrative Interfaces
- [ ] **ActiveAdmin Setup**
  Create comprehensive admin interfaces for system management:
  - Document management interface for uploaded documents
  - KG overview interface for browsing nodes/edges  
  - Category approval interface for new categories
  - Node type management and promotion interface

### API Development
- [ ] **RESTful API Endpoints**
  Create API for external system integration:
  - Document upload/management endpoints
  - Search API for querying documents and KG
  - KG query API for direct graph operations

### Testing Infrastructure
- [ ] **RSpec Testing Suite Setup**
  Replace current test suite with comprehensive RSpec framework:
  - Install and configure RSpec gems with test database
  - Set up factory_bot for test data generation
  - Create test helpers, shared examples, and coverage reporting
  - Unit tests for all services (LLM, KG, Document processing)
  - Integration tests for document import pipeline
  - System tests for admin interfaces
  - Mock LLM responses for consistent testing

## 2. Knowledge Graph Management
Core knowledge graph functionality and schema management.

### Schema and Type Management
- [ ] **In-Memory KG Schema Storage**
  Implement caching mechanism to store KG schema in memory for improved performance. Current schema is hardcoded in `KnowledgeGraph::BuildService`.

- [ ] **Category and Node Type Promotion Service**
  Build service layer to handle promotion of soft-types to node types and removal of obsolete categories with proper data migration.

### Node and Data Quality
- [ ] **Enhanced Node Descriptions**
  Expand node data structures to include more comprehensive and descriptive information for better user understanding and system utility.

- [ ] **LLM Node Validation Completion**
  Complete the implementation in `KnowledgeGraph::LlmValidationService` to validate and clean up extracted nodes using LLM.

## 3. Document Management System
Complete document lifecycle from import to deletion.

### Document Import
- [ ] **Document Upload and URL Import**
  Build user interface and backend functionality for document import:
  - File upload controller and form interface
  - URL fetching service for web content
  - Integration with document processing pipeline

- [ ] **Background Job Processing**
  Implement asynchronous job processing for document operations:
  - Background jobs for document processing
  - Job status tracking and progress monitoring
  - Error handling and retry logic

### Document Lifecycle
- [ ] **Cascading Document Deletion**
  Implement proper cleanup logic for document removal:
  - Document deletion service
  - KG cleanup logic for orphaned nodes/edges
  - Automated detection and removal of unlinked entities

## 4. Search and Query System
Comprehensive search capabilities combining similarity search with knowledge graph traversal.

### Query Processing Pipeline
- [ ] **Query Restructuring with LLM**
  Implement LLM-based query enhancement:
  - Transform user queries into optimized search terms
  - Extract key entities and intent from natural language
  - Generate alternative query formulations for better coverage

- [ ] **Query to KG Node Conversion**
  Build service to convert user queries into KG node representations:
  - Extract entities from query text
  - Map query concepts to existing KG node types
  - Generate query-specific node structures for graph traversal

### Multi-Modal Retrieval
- [ ] **Similarity Search Implementation**
  Implement vector-based similarity search:
  - Embed user queries for semantic similarity matching
  - Search against embedded document chunks and summaries
  - Apply configurable similarity thresholds (default ≥0.8)
  - Top-K quality filtering (max 5 results above threshold)

- [ ] **Knowledge Graph Traversal**
  Build KG traversal system for relationship-based discovery:
  - Two-hop node retrieval from search starting points
  - Edge confidence scoring based on extraction reliability
  - Related node collection with connecting edge information

### Search Interface and Results
- [ ] **Search Service and API**
  Build robust search service with multiple strategies:
  - Search controller and API endpoints
  - Integration with KG query service
  - Search results formatting and pagination
  - Document summary integration in results

### Confidence and Quality Management
- [ ] **Confidence Scoring System**
  Implement comprehensive confidence scoring:
  - Similarity score rescaling (0.8+ → 50-100% confidence range)
  - KG edge confidence based on extraction quality
  - Multi-source result aggregation with confidence weighting
  - Answer confidence calibration for generated responses

- [ ] **Source Linking and Transparency**
  Ensure response traceability:
  - Maintain source document references throughout pipeline
  - Provide direct links to original documents in responses
  - Include section/page references where applicable

## 5. Monitoring and Maintenance
System health, performance tracking, and operational management.

### Dashboard and Metrics
- [ ] **Enhanced Dashboard Metrics**
  Expand system dashboard beyond current cost metrics:
  - Total number of documents in system
  - KG node and edge counts
  - Search query success rates
  - Document processing status and errors

### Performance and Quality Monitoring
- [ ] **Query Performance Tracking**
  Implement monitoring for query system optimization:
  - Log query types, confidence distributions, and user feedback
  - Track success rates by query complexity and domain
  - Monitor retrieval coverage across different search methods
  - Dynamic threshold adjustment based on performance data

### Error Handling and Logging
- [ ] **Robust Error Management**
  Implement comprehensive error handling:
  - Structured logging for all KG operations
  - Error tracking and reporting systems
  - Monitoring dashboards for document processing status
  - Automated alerting for system issues

---