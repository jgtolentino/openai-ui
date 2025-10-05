# ETL Documentation - Next.js OpenAI Doc Search

**Purpose**: Document all Extract, Transform, Load (ETL) processes for embeddings generation and data ingestion
**Primary ETL**: MDX Documentation → OpenAI Embeddings → Supabase Database
**Secondary ETL**: PDF/Images → LandingAI OCR → Text Extraction

---

## 📊 ETL Overview

### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     ETL PIPELINE ARCHITECTURE                    │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Source Data │ ──▶ │  Transform   │ ──▶ │  Destination │
└──────────────┘     └──────────────┘     └──────────────┘
```

### ETL Processes

| Process | Source | Transform | Destination | Frequency |
|---------|--------|-----------|-------------|-----------|
| **Embeddings Generation** | .mdx files | MDX parsing → Chunking → OpenAI embeddings | Supabase (nods_page, nods_page_section) | Build time / On-demand |
| **Document OCR** | PDF/Images | File upload → LandingAI ADE | JSON response | Runtime / On-demand |
| **Search Query** | User input → OpenAI | Text → Embedding vector | Supabase similarity search | Runtime / Real-time |

---

## 🔄 ETL Process #1: Embeddings Generation

**Script**: `lib/generate-embeddings.ts`
**Trigger**: `pnpm run embeddings` or `pnpm build`
**Duration**: ~5-30 seconds per page (depends on content size)

### Process Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│              EMBEDDINGS GENERATION ETL PIPELINE                  │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐
│   EXTRACT    │
└──────────────┘
      │
      │ 1. Scan pages/ directory for .mdx files
      │ 2. Read file contents
      │ 3. Parse frontmatter and metadata
      ▼
┌──────────────┐
│  TRANSFORM   │
└──────────────┘
      │
      │ 1. Parse MDX to AST (Abstract Syntax Tree)
      │ 2. Extract heading structure
      │ 3. Split into sections by heading
      │ 4. Convert sections to plain text
      │ 5. Generate MD5 checksum
      │ 6. Check against existing checksums
      │ 7. For each new/changed section:
      │    a. Count tokens (GPT-3 tokenizer)
      │    b. Call OpenAI embeddings API
      │    c. Receive 1536-dimension vector
      ▼
┌──────────────┐
│     LOAD     │
└──────────────┘
      │
      │ 1. Upsert page record (nods_page)
      │ 2. Insert section records (nods_page_section)
      │ 3. Store embeddings as vector(1536)
      │ 4. Update checksum for change tracking
      ▼
┌──────────────┐
│   COMPLETE   │
└──────────────┘
```

### Detailed Steps

#### Step 1: EXTRACT - Source Data Discovery

**Input**: MDX files in `pages/**/*.mdx`
**Exclusions**: Files in `ignoredFiles` array (e.g., `pages/404.mdx`)

```typescript
// Discover all .mdx files
const sources = await walk(PAGES_DIR)
  .filter(({ path }) => /\.mdx?$/.test(path))
  .filter(({ path }) => !ignoredFiles.includes(path))
```

**Output**: Array of file paths

---

#### Step 2: TRANSFORM - MDX Parsing

**Parser**: `mdast-util-from-markdown` with `micromark-extension-mdxjs`

**Process**:
1. **Read file**: Load .mdx content as string
2. **Parse AST**: Convert to markdown AST (mdast)
3. **Extract metadata**: Extract MDX exports for frontmatter
4. **Build hierarchy**: Determine parent-child page relationships

```typescript
const content = await readFile(filePath, 'utf8')
const tree = fromMarkdown(content, {
  extensions: [mdxjs()],
  mdastExtensions: [mdxFromMarkdown()]
})
```

**AST Structure**:
```
root
├── mdxjsEsm (exports/imports)
├── heading (level 1-6)
│   └── text
├── paragraph
│   └── text
└── code
    └── value
```

---

#### Step 3: TRANSFORM - Section Splitting

**Strategy**: Split by headings to create semantic chunks

**Algorithm**:
1. Traverse AST nodes
2. On each heading (h1-h6):
   - Create new section
   - Generate slug from heading text
   - Accumulate content until next heading
3. Filter out sections without meaningful content

```typescript
for (const node of tree.children) {
  if (node.type === 'heading') {
    currentSection = {
      heading: toString(node),
      slug: slugger.slug(toString(node)),
      content: []
    }
    sections.push(currentSection)
  } else {
    currentSection.content.push(node)
  }
}
```

**Output**: Array of sections with heading, slug, and content

---

#### Step 4: TRANSFORM - Text Extraction

**Process**: Convert AST nodes back to plain text

```typescript
const sectionText = toMarkdown({
  type: 'root',
  children: section.content
})
```

**Cleaning**:
- Remove excessive whitespace
- Normalize line breaks
- Strip control characters

---

#### Step 5: TRANSFORM - Checksum Generation

**Purpose**: Detect content changes to avoid redundant processing

**Algorithm**: MD5 hash of entire file content

```typescript
const checksum = createHash('md5')
  .update(fileContent)
  .digest('base64')
```

**Comparison**:
```typescript
if (existingPage?.checksum === checksum && !shouldRefresh) {
  console.log('No changes detected, skipping...')
  return
}
```

---

#### Step 6: TRANSFORM - Token Counting

**Tokenizer**: GPT-3 tokenizer (`gpt3-tokenizer`)

**Purpose**: Track token usage for cost estimation and context limits

```typescript
import { encode } from 'gpt3-tokenizer'

const tokenCount = encode(sectionText).length
```

**Token Limits**:
- Max input: 8,191 tokens (text-embedding-ada-002)
- Typical section: 50-500 tokens

---

#### Step 7: TRANSFORM - OpenAI Embeddings API

**Model**: `text-embedding-ada-002`
**Dimensions**: 1536
**Cost**: $0.0001 per 1K tokens

**API Call**:
```typescript
const embeddingResponse = await openai.createEmbedding({
  model: 'text-embedding-ada-002',
  input: sectionText
})

const embedding = embeddingResponse.data.data[0].embedding
// Returns: [0.023, -0.015, 0.041, ...] (1536 numbers)
```

**Error Handling**:
- Retry on rate limits (429)
- Skip sections >8K tokens
- Log failures without blocking entire process

---

#### Step 8: LOAD - Database Storage

**Database**: Supabase PostgreSQL with pgvector

**Operations**:

1. **Upsert Page**:
```typescript
const { data: page } = await supabaseClient
  .from('nods_page')
  .upsert({
    path: pagePath,
    checksum: checksum,
    meta: metadata,
    parent_page_id: parentPageId
  })
  .select()
  .single()
```

2. **Insert Sections**:
```typescript
for (const section of sections) {
  await supabaseClient
    .from('nods_page_section')
    .insert({
      page_id: page.id,
      content: section.text,
      token_count: section.tokenCount,
      embedding: section.embedding,  // vector(1536)
      slug: section.slug,
      heading: section.heading
    })
}
```

3. **Update Checksum**:
```typescript
await supabaseClient
  .from('nods_page')
  .update({ checksum: checksum })
  .eq('id', page.id)
```

---

### Performance Metrics

| Metric | Value |
|--------|-------|
| **Processing Time** | ~2-5 seconds per section |
| **OpenAI API Latency** | ~500-1500ms per embedding |
| **Database Write** | ~50-100ms per insert |
| **Total Duration** | ~5-30 seconds per page |

### Error Handling

| Error Type | Handling Strategy |
|-----------|-------------------|
| **File Read Error** | Skip file, log error, continue |
| **MDX Parse Error** | Skip file, log error, continue |
| **OpenAI API Error** | Retry 3x with exponential backoff |
| **Database Error** | Mark page with null checksum, retry later |
| **Token Limit Exceeded** | Skip section, log warning |

---

## 🔄 ETL Process #2: Document OCR (LandingAI)

**API Route**: `pages/api/ocr.ts`
**Trigger**: User file upload via `<DocumentUpload />` component
**Duration**: ~3-10 seconds per document

### Process Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                  DOCUMENT OCR ETL PIPELINE                       │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐
│   EXTRACT    │
└──────────────┘
      │
      │ 1. User uploads PDF or image file
      │ 2. Browser sends multipart/form-data
      │ 3. API receives File blob
      ▼
┌──────────────┐
│  TRANSFORM   │
└──────────────┘
      │
      │ 1. Validate file type (PDF, PNG, JPG, WebP)
      │ 2. Convert to Buffer
      │ 3. Call LandingAI ADE API
      │    - Upload document
      │    - Process with OCR
      │    - Extract text, tables, structure
      │ 4. Receive parsed document:
      │    - markdown: Plain text version
      │    - chunks: Structured sections
      │    - splits: Page-by-page content
      │    - metadata: Processing info
      ▼
┌──────────────┐
│     LOAD     │
└──────────────┘
      │
      │ 1. Return JSON response to client
      │ 2. Client can display or store
      │ 3. Optional: Store in database
      │ 4. Optional: Generate embeddings
      ▼
┌──────────────┐
│   COMPLETE   │
└──────────────┘
```

### Detailed Steps

#### Step 1: EXTRACT - File Upload

**Input**: Multipart form data with file
**Supported Formats**: PDF, PNG, JPG, JPEG, WebP

```typescript
const formData = await req.formData()
const file = formData.get('file') as File
```

**Validation**:
```typescript
const allowedTypes = [
  'application/pdf',
  'image/png',
  'image/jpeg',
  'image/jpg',
  'image/webp'
]

if (!allowedTypes.includes(file.type)) {
  return error('Invalid file type')
}
```

---

#### Step 2: TRANSFORM - LandingAI OCR

**API**: LandingAI Agentic Document Extraction (ADE)
**Endpoint**: `https://api.va.landing.ai/v1/ade/parse`

**Request**:
```typescript
const client = getLandingAIClient()
const arrayBuffer = await file.arrayBuffer()
const buffer = Buffer.from(arrayBuffer)

const result = await client.parseDocument(buffer, {
  split: 'page'  // Optional: split by page
})
```

**LandingAI Processing**:
1. Document upload to cloud storage
2. OCR engine processes document
3. Layout analysis identifies structure
4. Text extraction with coordinates
5. Table detection and parsing
6. Markdown generation

**API Response Structure**:
```typescript
{
  markdown: "# Document Title\n\nParagraph text...",
  chunks: [
    {
      text: "Section 1 content",
      metadata: { page: 1, coordinates: [...] }
    }
  ],
  splits: [
    { page: 1, content: "Page 1 text..." },
    { page: 2, content: "Page 2 text..." }
  ],
  metadata: {
    pages: 3,
    processingTime: 2500
  }
}
```

---

#### Step 3: LOAD - Response Formatting

**Output Formats**:

1. **JSON** (default):
```json
{
  "success": true,
  "data": {
    "markdown": "...",
    "chunks": [...],
    "splits": [...],
    "metadata": {...}
  }
}
```

2. **Text** (`format=text`):
```
Plain text extracted from document...
```

3. **Markdown** (`format=markdown`):
```markdown
# Heading
Content with formatting...
```

---

### Performance Metrics

| Metric | Value |
|--------|-------|
| **Upload Time** | ~100-500ms |
| **LandingAI Processing** | ~2-8 seconds |
| **Response Time** | ~3-10 seconds total |
| **Max File Size** | 10MB (recommended) |

### Error Handling

| Error Type | HTTP Status | Message |
|-----------|-------------|---------|
| **No File** | 400 | "No file provided" |
| **Invalid Type** | 400 | "Invalid file type. Supported: PDF, PNG, JPEG, WebP" |
| **LandingAI Error** | 500 | "Failed to process document: [details]" |
| **Network Error** | 500 | "LandingAI API error: [status]" |

---

## 🔄 ETL Process #3: Search Query (Runtime)

**API Route**: `pages/api/vector-search.ts`
**Trigger**: User submits search query
**Duration**: ~500-1500ms per query

### Process Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                  SEARCH QUERY ETL PIPELINE                       │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐
│   EXTRACT    │
└──────────────┘
      │
      │ 1. User types search query
      │ 2. Client sends POST request
      │ 3. API receives query string
      ▼
┌──────────────┐
│  TRANSFORM   │
└──────────────┘
      │
      │ 1. Generate query embedding (OpenAI)
      │ 2. Call match_page_sections() function
      │ 3. Supabase performs vector similarity search
      │ 4. Retrieve top N matching sections
      │ 5. Combine sections into context
      │ 6. Build GPT prompt with context
      │ 7. Call OpenAI Chat Completion
      ▼
┌──────────────┐
│     LOAD     │
└──────────────┘
      │
      │ 1. Stream response to client
      │ 2. Client displays answer
      │ 3. Show source sections
      ▼
┌──────────────┐
│   COMPLETE   │
└──────────────┘
```

### Detailed Steps

#### Step 1: EXTRACT - Query Input

**Input**: User search query string

```typescript
const { query } = await req.json()
// Example: "How do I use embeddings?"
```

---

#### Step 2: TRANSFORM - Query Embedding

**API**: OpenAI Embeddings API

```typescript
const embeddingResponse = await openai.createEmbedding({
  model: 'text-embedding-ada-002',
  input: query
})

const queryEmbedding = embeddingResponse.data.data[0].embedding
// Returns: [0.012, -0.034, 0.056, ...] (1536 dimensions)
```

---

#### Step 3: TRANSFORM - Similarity Search

**Database Function**: `match_page_sections()`

```typescript
const { data: sections } = await supabaseClient.rpc(
  'match_page_sections',
  {
    embedding: queryEmbedding,
    match_threshold: 0.78,  // 78% similarity
    match_count: 10,        // Top 10 results
    min_content_length: 50  // Min 50 chars
  }
)
```

**Result**:
```typescript
[
  {
    id: 1,
    content: "Embeddings are...",
    similarity: 0.92,
    heading: "What are Embeddings?",
    ...
  },
  ...
]
```

---

#### Step 4: TRANSFORM - Context Building

**Process**: Combine sections into GPT context

```typescript
const contextText = sections
  .map(section => section.content)
  .join('\n\n---\n\n')
```

**Token Management**:
- Max context: ~3000 tokens
- Trim if exceeds limit

---

#### Step 5: TRANSFORM - GPT Completion

**Model**: GPT-3.5-turbo or GPT-4
**Mode**: Streaming

```typescript
const completion = await openai.createChatCompletion({
  model: 'gpt-3.5-turbo',
  messages: [
    {
      role: 'system',
      content: 'You are a helpful assistant...'
    },
    {
      role: 'user',
      content: `Context:\n${contextText}\n\nQuestion: ${query}`
    }
  ],
  stream: true
})
```

---

#### Step 6: LOAD - Stream Response

**Protocol**: Server-Sent Events (SSE)

```typescript
const encoder = new TextEncoder()

for await (const chunk of completion) {
  const text = chunk.choices[0]?.delta?.content || ''

  yield encoder.encode(`data: ${JSON.stringify({ text })}\n\n`)
}
```

**Client receives**: Real-time text chunks

---

### Performance Metrics

| Step | Duration |
|------|----------|
| **Query Embedding** | ~200-500ms |
| **Similarity Search** | ~50-150ms |
| **GPT Completion (first token)** | ~500-1000ms |
| **Full Response** | ~2-5 seconds |
| **Total (TTFB)** | ~750-1650ms |

---

## 📊 ETL Monitoring & Observability

### Key Metrics to Track

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| **Embeddings Success Rate** | >95% | <90% |
| **OpenAI API Latency (P95)** | <2s | >5s |
| **Database Write Success** | 100% | <99% |
| **OCR Success Rate** | >90% | <80% |
| **Search Response Time (P95)** | <2s | >5s |

### Logging Best Practices

**Log Levels**:
- **INFO**: Normal operations, page processed
- **WARN**: Retries, skipped sections
- **ERROR**: Failures requiring attention

**Example Logs**:
```
[INFO] [/docs/getting-started] Adding 5 page sections (with embeddings)
[WARN] [/docs/api] Section too large (9000 tokens), skipping
[ERROR] [/docs/guide] OpenAI API error: Rate limit exceeded
```

---

## 🛠️ ETL Maintenance

### Daily Operations

- [ ] Monitor embedding success rate
- [ ] Check OpenAI API usage/costs
- [ ] Review error logs
- [ ] Verify database health

### Weekly Operations

- [ ] Regenerate embeddings for changed content
- [ ] Vacuum/analyze database tables
- [ ] Review OCR usage and costs
- [ ] Update documentation

### Monthly Operations

- [ ] Full embeddings refresh
- [ ] Database backup
- [ ] Cost analysis and optimization
- [ ] Performance tuning

---

## 📈 Scaling Considerations

### Current Capacity

| Resource | Current | Max Capacity |
|----------|---------|--------------|
| **Pages** | 1 | ~10,000 |
| **Sections** | 2 | ~100,000 |
| **Embeddings** | 2 | ~100,000 |
| **Daily Searches** | <100 | ~10,000 |

### Optimization Strategies

1. **Batch Processing**: Process multiple sections in parallel
2. **Caching**: Cache embeddings, avoid regeneration
3. **Incremental Updates**: Only process changed files
4. **Database Indexing**: Add ivfflat index for fast search

---

**Last Updated**: 2025-10-06
**ETL Version**: 1.0.0
