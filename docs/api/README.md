# Sage API Documentation

## Quick Start

### 1. Login
```bash
curl -X POST http://localhost:3000/api/v1/admin_users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'
```

Response:
```json
{
  "auth_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### 2. Send Query
```bash
curl -X POST http://localhost:3000/api/v1/prompts/process \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"text_summarization","query":"Summarize this"}'
```

Response:
```json
{
  "success": true,
  "data": {
    "response": "The document discusses...",
    "prompt_name": "text_summarization",
    "original_query": "Summarize this",
    "ai_log_id": 12345,
    "processed_prompt": "Full prompt with variables"
  }
}
```

### 3. Logout
```bash
curl -X POST http://localhost:3000/api/v1/admin_users/logout \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"YOUR_REFRESH_TOKEN"}'
```

---

## Base URL

```
http://localhost:3000/api/v1
```

## Authentication

All endpoints (except login) require JWT Bearer token authentication:

```
Authorization: Bearer <access_token>
```

## Response Format

### Success
```json
{
  "success": true,
  "data": { /* endpoint-specific */ }
}
```

### Error
```json
{
  "success": false,
  "error": "Error message"
}
```

## Status Codes

- `200 OK` - Success
- `400 Bad Request` - Invalid parameters
- `401 Unauthorized` - Missing or invalid token
- `404 Not Found` - Resource not found
- `500 Internal Server Error` - Server error

## Endpoints

### Authentication
See [authentication.md](./authentication.md)
- `POST /admin_users/login`
- `POST /admin_users/refresh`
- `POST /admin_users/logout`
- `POST /admin_users/logout_all`

### Prompts
See [prompts.md](./prompts.md)
- `POST /prompts/process`

