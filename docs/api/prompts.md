# Prompts Endpoint

## Process Prompt

**Endpoint:** `POST /prompts/process`

Send a query to an AI model using a predefined prompt template.

**Authentication:** Required (Bearer token)

### Request

```json
{
  "prompt": "text_summarization",
  "query": "Summarize this document...",
  "chat_id": "user-123-session-1",
  "temperature": 0.7,
  "model": "google/gemini-2.0-flash-001",
  "custom_param_1": "value1"
}
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `prompt` | string | Yes | Name of the prompt template to use |
| `query` | string | No | The user's question or message |
| `chat_id` | string | No | Conversation ID for grouping related queries |
| `temperature` | float | No | Model temperature (0.0-1.0), default: 0.7 |
| `model` | string | No | AI model to use, overrides default |
| `*` | any | No | Additional parameters for prompt variables |

### Response (Success - 200)

```json
{
  "success": true,
  "data": {
    "response": "The document discusses...",
    "prompt_name": "text_summarization",
    "original_query": "Summarize this document...",
    "ai_log_id": 12345,
    "processed_prompt": "Full prompt with variables substituted"
  }
}
```

### Response (Error - 404)

```json
{
  "success": false,
  "error": "Prompt 'invalid_prompt' not found"
}
```

### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `response` | string | The AI model's response |
| `prompt_name` | string | Name of the prompt template used |
| `original_query` | string | The original user query |
| `ai_log_id` | integer | ID of the log entry (for tracking) |
| `processed_prompt` | string | Full prompt with all variables substituted |

### Status Codes
- `200 OK` - Request successful
- `400 Bad Request` - Missing required parameters
- `401 Unauthorized` - Invalid or missing authentication
- `404 Not Found` - Prompt template not found
- `500 Internal Server Error` - Server error

### Examples

**cURL**
```bash
curl -X POST http://localhost:3000/api/v1/prompts/process \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "text_summarization",
    "query": "Summarize this document",
    "chat_id": "user-123-session-1"
  }'
```

**JavaScript**
```javascript
const response = await fetch('http://localhost:3000/api/v1/prompts/process', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${accessToken}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    prompt: 'text_summarization',
    query: 'Summarize this document',
    chat_id: 'user-123-session-1'
  })
});

const data = await response.json();
console.log(data.data.response);
```

**Python**
```python
import requests

response = requests.post(
    'http://localhost:3000/api/v1/prompts/process',
    headers={'Authorization': f'Bearer {access_token}'},
    json={
        'prompt': 'text_summarization',
        'query': 'Summarize this document',
        'chat_id': 'user-123-session-1'
    }
)

data = response.json()
print(data['data']['response'])
```

### Notes

- The `prompt` parameter is required
- The `query` parameter is optional but recommended
- Additional parameters are passed to the prompt template as variables
- The `ai_log_id` can be used to track the request in logs
- Response time depends on the AI model and query complexity
- The `processed_prompt` shows the final prompt sent to the AI model

