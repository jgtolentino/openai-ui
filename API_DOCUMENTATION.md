# API Documentation - Next.js OpenAI Doc Search

**Base URL**: `http://localhost:3001` (Development) | `https://[your-domain].vercel.app` (Production)
**API Version**: 1.0.0
**Authentication**: None (public APIs)

---

## 📚 API Overview

### Available Endpoints

| Endpoint | Method | Purpose | Status |
|----------|--------|---------|--------|
| `/api/vector-search` | POST | Semantic search with OpenAI | ✅ Core |
| `/api/ocr` | POST | Document OCR extraction | 🆕 New |

### API Standards

- **Protocol**: HTTPS (production), HTTP (development)
- **Format**: JSON request/response
- **Content-Type**: `application/json` (search), `multipart/form-data` (OCR)
- **Response Format**: Consistent JSON structure
- **Error Handling**: Standard HTTP status codes with error details
- **Rate Limiting**: None (relies on OpenAI/LandingAI limits)

---

## 🔍 API Endpoint #1: Vector Search

**Purpose**: Perform semantic search on documentation using OpenAI embeddings

### Endpoint Details

```
POST /api/vector-search
```

### Request

**Headers**:
```http
Content-Type: application/json
```

**Body Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | ✅ Yes | User search query (e.g., "How do embeddings work?") |

**Request Example**:
```bash
curl -X POST http://localhost:3001/api/vector-search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "How do I use OpenAI embeddings?"
  }'
```

**Request Body (JSON)**:
```json
{
  "query": "How do I use OpenAI embeddings?"
}
```

---

### Response

**Content-Type**: `text/event-stream` (Server-Sent Events for streaming)

**Response Format**: SSE Stream

```
data: {"text":"Embeddings"}

data: {"text":" are"}

data: {"text":" numerical"}

data: {"text":" representations"}

...

data: [DONE]
```

**Event Types**:
| Event | Data | Description |
|-------|------|-------------|
| `data: {...}` | `{ text: string }` | Text chunk from GPT completion |
| `data: [DONE]` | End marker | Stream completion |

**Streaming Example (JavaScript)**:
```javascript
const response = await fetch('/api/vector-search', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ query: 'How do embeddings work?' })
})

const reader = response.body.getReader()
const decoder = new TextDecoder()

while (true) {
  const { done, value } = await reader.read()
  if (done) break

  const chunk = decoder.decode(value)
  const lines = chunk.split('\n')

  for (const line of lines) {
    if (line.startsWith('data: ')) {
      const data = line.slice(6)
      if (data === '[DONE]') break

      const json = JSON.parse(data)
      console.log(json.text)  // "Embeddings", " are", ...
    }
  }
}
```

---

### Error Responses

**400 Bad Request**:
```json
{
  "error": "Missing query parameter"
}
```

**500 Internal Server Error**:
```json
{
  "error": "Failed to process search query",
  "details": "OpenAI API error: Rate limit exceeded"
}
```

**Error Status Codes**:
| Code | Description | Common Causes |
|------|-------------|---------------|
| 400 | Bad Request | Missing `query` parameter |
| 500 | Internal Server Error | OpenAI API failure, Database connection error |
| 503 | Service Unavailable | Supabase unavailable |

---

### Implementation Details

**Process Flow**:
1. Receive query → Generate embedding (OpenAI)
2. Similarity search (Supabase `match_page_sections`)
3. Retrieve relevant sections
4. Build context from sections
5. GPT completion with context (streaming)
6. Stream response to client

**Technologies**:
- **OpenAI**: text-embedding-ada-002 (embeddings), gpt-3.5-turbo (completion)
- **Database**: Supabase pgvector for similarity search
- **Streaming**: Server-Sent Events (SSE)

**Performance**:
- **Time to First Byte (TTFB)**: ~750-1500ms
- **Full Response**: ~2-5 seconds
- **Embedding Generation**: ~200-500ms
- **Vector Search**: ~50-150ms

---

### Usage Example (React)

```typescript
import { useState } from 'react'

function SearchComponent() {
  const [query, setQuery] = useState('')
  const [response, setResponse] = useState('')

  const handleSearch = async () => {
    const res = await fetch('/api/vector-search', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query })
    })

    const reader = res.body.getReader()
    const decoder = new TextDecoder()

    while (true) {
      const { done, value } = await reader.read()
      if (done) break

      const chunk = decoder.decode(value)
      const lines = chunk.split('\n')

      for (const line of lines) {
        if (line.startsWith('data: ')) {
          const data = line.slice(6)
          if (data === '[DONE]') break

          const { text } = JSON.parse(data)
          setResponse(prev => prev + text)
        }
      }
    }
  }

  return (
    <div>
      <input
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Ask a question..."
      />
      <button onClick={handleSearch}>Search</button>
      <div>{response}</div>
    </div>
  )
}
```

---

## 📄 API Endpoint #2: Document OCR

**Purpose**: Extract text from PDF and image files using LandingAI OCR

### Endpoint Details

```
POST /api/ocr
```

### Request

**Headers**:
```http
Content-Type: multipart/form-data
```

**Form Data Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | File | ✅ Yes | PDF or image file (PNG, JPG, JPEG, WebP) |
| `split` | string | ❌ No | Split mode: `page` to split by page |
| `format` | string | ❌ No | Response format: `json` (default), `text`, `markdown` |

**Request Example (cURL)**:
```bash
curl -X POST http://localhost:3001/api/ocr \
  -F "file=@document.pdf" \
  -F "split=page" \
  -F "format=json"
```

**Request Example (JavaScript)**:
```javascript
const formData = new FormData()
formData.append('file', fileInput.files[0])
formData.append('split', 'page')
formData.append('format', 'json')

const response = await fetch('/api/ocr', {
  method: 'POST',
  body: formData
})

const result = await response.json()
```

---

### Response

**Format**: JSON (default), Text, or Markdown

**JSON Response** (`format=json`):
```json
{
  "success": true,
  "data": {
    "markdown": "# Document Title\n\nParagraph content...",
    "chunks": [
      {
        "text": "Section 1 content",
        "metadata": {
          "page": 1,
          "coordinates": [...]
        }
      }
    ],
    "splits": [
      {
        "page": 1,
        "content": "Page 1 text..."
      },
      {
        "page": 2,
        "content": "Page 2 text..."
      }
    ],
    "metadata": {
      "pages": 2,
      "processingTime": 3200
    }
  }
}
```

**Text Response** (`format=text`):
```
Content-Type: text/plain

Document Title

Paragraph content...
```

**Markdown Response** (`format=markdown`):
```
Content-Type: text/markdown

# Document Title

Paragraph content...
```

---

### Response Fields

#### Top-Level Fields
| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | Whether operation succeeded |
| `data` | object | Parsed document data |

#### Data Object Fields
| Field | Type | Description |
|-------|------|-------------|
| `markdown` | string | Full document as markdown text |
| `chunks` | array | Structured sections with metadata |
| `splits` | array | Page-by-page content (if `split=page`) |
| `metadata` | object | Processing information |

#### Chunk Object
| Field | Type | Description |
|-------|------|-------------|
| `text` | string | Section text content |
| `metadata` | object | Page number, coordinates, etc. |

#### Split Object
| Field | Type | Description |
|-------|------|-------------|
| `page` | number | Page number (1-indexed) |
| `content` | string | Page text content |

#### Metadata Object
| Field | Type | Description |
|-------|------|-------------|
| `pages` | number | Total page count |
| `processingTime` | number | Processing time in milliseconds |

---

### Error Responses

**400 Bad Request - No File**:
```json
{
  "error": "No file provided"
}
```

**400 Bad Request - Invalid File Type**:
```json
{
  "error": "Invalid file type. Supported: PDF, PNG, JPEG, WebP"
}
```

**500 Internal Server Error**:
```json
{
  "error": "Failed to process document",
  "details": "LandingAI API error: 429 - Rate limit exceeded"
}
```

**Error Status Codes**:
| Code | Description | Common Causes |
|------|-------------|---------------|
| 400 | Bad Request | Missing file, invalid file type |
| 405 | Method Not Allowed | Non-POST request |
| 413 | Payload Too Large | File exceeds size limit |
| 500 | Internal Server Error | LandingAI API failure, Network error |

---

### Supported File Types

| Format | Extension | MIME Type | Max Size |
|--------|-----------|-----------|----------|
| PDF | `.pdf` | `application/pdf` | 10MB |
| PNG | `.png` | `image/png` | 10MB |
| JPEG | `.jpg`, `.jpeg` | `image/jpeg` | 10MB |
| WebP | `.webp` | `image/webp` | 10MB |

---

### Implementation Details

**Process Flow**:
1. Receive file upload → Validate type/size
2. Convert to Buffer → Send to LandingAI ADE API
3. LandingAI processes → Returns parsed document
4. Format response → Return to client

**Technologies**:
- **LandingAI**: Agentic Document Extraction (ADE) API
- **Processing**: OCR, layout analysis, table detection
- **Output**: Markdown, JSON chunks, page splits

**Performance**:
- **Upload Time**: ~100-500ms
- **LandingAI Processing**: ~2-8 seconds
- **Total Response Time**: ~3-10 seconds

---

### Usage Example (React Component)

```typescript
import { useState } from 'react'

function DocumentUpload() {
  const [result, setResult] = useState(null)
  const [isProcessing, setIsProcessing] = useState(false)

  const handleUpload = async (event) => {
    const file = event.target.files[0]
    if (!file) return

    setIsProcessing(true)

    const formData = new FormData()
    formData.append('file', file)
    formData.append('split', 'page')

    try {
      const response = await fetch('/api/ocr', {
        method: 'POST',
        body: formData
      })

      const data = await response.json()
      setResult(data.data)
    } catch (error) {
      console.error('OCR failed:', error)
    } finally {
      setIsProcessing(false)
    }
  }

  return (
    <div>
      <input
        type="file"
        accept=".pdf,.png,.jpg,.jpeg,.webp"
        onChange={handleUpload}
      />
      {isProcessing && <p>Processing...</p>}
      {result && (
        <div>
          <h3>Extracted Content:</h3>
          <pre>{result.markdown}</pre>
          <p>Pages: {result.metadata.pages}</p>
        </div>
      )}
    </div>
  )
}
```

---

## 🔐 Security Considerations

### API Security

**Current State**:
- ✅ No authentication required (public APIs)
- ✅ Server-side API keys (never exposed to client)
- ✅ Input validation on all endpoints
- ⚠️ No rate limiting (relies on provider limits)

**Recommendations**:
- [ ] Add authentication for production
- [ ] Implement rate limiting per IP/user
- [ ] Add CORS configuration
- [ ] Monitor for abuse

### Environment Variables

**Required**:
- `NEXT_PUBLIC_SUPABASE_URL` (public)
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` (public)
- `SUPABASE_SERVICE_ROLE_KEY` (secret - server only)
- `OPENAI_KEY` (secret - server only)
- `LANDINGAI_API_KEY` (secret - server only)

**Security**:
- ✅ Service role keys never sent to browser
- ✅ API routes run server-side (Edge Runtime)
- ✅ Environment variables encrypted in Vercel

---

## 📊 API Monitoring

### Key Metrics

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| **Search Response Time (P95)** | <2s | >5s |
| **OCR Response Time (P95)** | <10s | >20s |
| **Success Rate** | >99% | <95% |
| **Error Rate** | <1% | >5% |

### Error Tracking

**Common Errors**:
1. **OpenAI Rate Limits**: 429 errors → Implement exponential backoff
2. **Supabase Timeouts**: Connection issues → Check database status
3. **LandingAI Failures**: OCR processing errors → Validate input files
4. **Network Errors**: Timeout/connection → Retry logic

---

## 🚀 Rate Limits

### Provider Limits

| Provider | Limit | Period | Scope |
|----------|-------|--------|-------|
| **OpenAI** | 3,000 requests | 1 minute | Organization |
| **LandingAI** | 100 requests | 1 hour | API key |
| **Supabase** | 500 concurrent connections | - | Project |

### Best Practices

1. **Client-side Debouncing**: Delay search queries by 300-500ms
2. **Caching**: Cache search results for repeated queries
3. **Retry Logic**: Exponential backoff on rate limit errors
4. **Monitoring**: Track usage to stay within limits

---

## 🧪 Testing

### Manual Testing

**Search API**:
```bash
# Test search
curl -X POST http://localhost:3001/api/vector-search \
  -H "Content-Type: application/json" \
  -d '{"query":"What are embeddings?"}'
```

**OCR API**:
```bash
# Test OCR
curl -X POST http://localhost:3001/api/ocr \
  -F "file=@test.pdf" \
  -F "format=json"
```

### Integration Tests

**Test Cases**:
- [ ] Search with valid query
- [ ] Search with empty query (should error)
- [ ] OCR with PDF file
- [ ] OCR with image file
- [ ] OCR with invalid file type (should error)
- [ ] OCR with no file (should error)

---

## 📚 API Client Libraries

### JavaScript/TypeScript

**Fetch API** (Built-in):
```typescript
// Search
const searchResult = await fetch('/api/vector-search', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ query: 'test' })
})

// OCR
const formData = new FormData()
formData.append('file', file)
const ocrResult = await fetch('/api/ocr', {
  method: 'POST',
  body: formData
})
```

### Python

```python
import requests

# Search
response = requests.post(
    'http://localhost:3001/api/vector-search',
    json={'query': 'What are embeddings?'}
)

# OCR
with open('document.pdf', 'rb') as f:
    response = requests.post(
        'http://localhost:3001/api/ocr',
        files={'file': f}
    )
```

---

## 🔄 Versioning

**Current Version**: 1.0.0

**Versioning Strategy**: Semantic Versioning (SemVer)
- **Major**: Breaking changes to API contract
- **Minor**: New features, backward-compatible
- **Patch**: Bug fixes, backward-compatible

**Future Versions**:
- `1.1.0`: Add authentication
- `1.2.0`: Add rate limiting
- `2.0.0`: Breaking changes to response format

---

## 📞 Support

### Resources

- **API Issues**: https://github.com/jgtolentino/nextjs-openai-doc-search-starter/issues
- **OpenAI Docs**: https://platform.openai.com/docs
- **LandingAI Docs**: https://docs.landing.ai
- **Supabase Docs**: https://supabase.com/docs

### Common Questions

**Q: Why is search slow?**
A: Initial cold starts can take 2-5 seconds. Subsequent requests are faster.

**Q: Why did OCR fail?**
A: Check file type (must be PDF/image), size (<10MB), and LandingAI API status.

**Q: How do I add authentication?**
A: Implement Next.js middleware to verify auth tokens before allowing API access.

---

**Last Updated**: 2025-10-06
**API Version**: 1.0.0
