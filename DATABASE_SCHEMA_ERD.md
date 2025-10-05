# Database Schema & ERD - Next.js OpenAI Doc Search

**Database**: Supabase PostgreSQL with pgvector extension
**Schema Version**: 20230406025118_init
**Purpose**: Store documentation pages and vector embeddings for semantic search

---

## 📊 Entity Relationship Diagram (ERD)

### Visual Schema

```
┌─────────────────────────────────────────┐
│          nods_page                      │
├─────────────────────────────────────────┤
│ PK  id                 BIGSERIAL        │
│ FK  parent_page_id     BIGINT          │◄────┐
│     path               TEXT UNIQUE      │     │ Self-referencing
│     checksum           TEXT             │     │ for parent pages
│     meta               JSONB            │     │
│     type               TEXT             │     │
│     source             TEXT             │─────┘
└─────────────────────────────────────────┘
                │
                │ 1:N
                ▼
┌─────────────────────────────────────────┐
│      nods_page_section                  │
├─────────────────────────────────────────┤
│ PK  id                 BIGSERIAL        │
│ FK  page_id            BIGINT  NOT NULL │
│     content            TEXT             │
│     token_count        INT              │
│     embedding          VECTOR(1536)     │◄─── OpenAI Embeddings
│     slug               TEXT             │
│     heading            TEXT             │
└─────────────────────────────────────────┘
```

### Relationships

| Type | From | To | Description |
|------|------|----|-----------

|
| **1:N** | `nods_page` | `nods_page_section` | One page has many sections |
| **Self-Referencing** | `nods_page` | `nods_page` | Pages can have parent pages (hierarchy) |
| **Cascade Delete** | `nods_page` → `nods_page_section` | Deleting a page deletes all sections |

---

## 🗂️ Table Schemas

### Table: `nods_page`

**Purpose**: Stores documentation page metadata and hierarchy

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `BIGSERIAL` | PRIMARY KEY | Auto-incrementing unique identifier |
| `parent_page_id` | `BIGINT` | FOREIGN KEY → `nods_page.id` | Parent page for hierarchical structure |
| `path` | `TEXT` | NOT NULL, UNIQUE | Page path (e.g., `/docs/getting-started`) |
| `checksum` | `TEXT` | - | MD5 hash of content for change detection |
| `meta` | `JSONB` | - | Arbitrary metadata (title, description, tags) |
| `type` | `TEXT` | - | Page type (e.g., `doc`, `guide`, `api`) |
| `source` | `TEXT` | - | Source file path or origin |

**Indexes**:
- Primary key on `id`
- Unique constraint on `path`
- Foreign key index on `parent_page_id`

**Row Level Security**: ENABLED (policies required for access)

**Example Row**:
```json
{
  "id": 1,
  "parent_page_id": null,
  "path": "/docs/openai_embeddings",
  "checksum": "a3f7b8c9d1e2f3g4h5i6",
  "meta": {
    "title": "OpenAI Embeddings Guide",
    "description": "Learn how to use OpenAI embeddings"
  },
  "type": "doc",
  "source": "pages/docs/openai_embeddings.mdx"
}
```

---

### Table: `nods_page_section`

**Purpose**: Stores page sections with OpenAI embeddings for semantic search

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `BIGSERIAL` | PRIMARY KEY | Auto-incrementing unique identifier |
| `page_id` | `BIGINT` | NOT NULL, FOREIGN KEY → `nods_page.id` ON DELETE CASCADE | Parent page reference |
| `content` | `TEXT` | - | Section text content |
| `token_count` | `INT` | - | Number of tokens in content |
| `embedding` | `VECTOR(1536)` | - | OpenAI text-embedding-ada-002 vector |
| `slug` | `TEXT` | - | Section URL slug (e.g., `#introduction`) |
| `heading` | `TEXT` | - | Section heading text |

**Indexes**:
- Primary key on `id`
- Foreign key index on `page_id`
- **Vector index** on `embedding` for similarity search (ivfflat)

**Row Level Security**: ENABLED (policies required for access)

**Example Row**:
```json
{
  "id": 1,
  "page_id": 1,
  "content": "Embeddings are numerical representations of text that capture semantic meaning...",
  "token_count": 150,
  "embedding": [0.023, -0.015, 0.041, ...], // 1536 dimensions
  "slug": "what-are-embeddings",
  "heading": "What are Embeddings?"
}
```

---

## 🔧 Database Functions

### Function: `match_page_sections()`

**Purpose**: Perform vector similarity search to find relevant sections

**Signature**:
```sql
CREATE FUNCTION match_page_sections(
  embedding vector(1536),
  match_threshold float,
  match_count int,
  min_content_length int
)
RETURNS TABLE (
  id bigint,
  page_id bigint,
  slug text,
  heading text,
  content text,
  similarity float
)
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `embedding` | `vector(1536)` | Query embedding from OpenAI |
| `match_threshold` | `float` | Minimum similarity score (0-1) |
| `match_count` | `int` | Maximum number of results |
| `min_content_length` | `int` | Minimum content length filter |

**Returns**: Table of matching sections with similarity scores

**Algorithm**:
1. Computes dot product similarity: `embedding <#> query_embedding`
2. Filters by `match_threshold` and `min_content_length`
3. Orders by similarity (descending)
4. Limits to `match_count` results

**Example Usage**:
```sql
SELECT * FROM match_page_sections(
  '[0.023, -0.015, ...]'::vector(1536),  -- Query embedding
  0.7,                                     -- 70% similarity threshold
  5,                                       -- Top 5 results
  50                                       -- Min 50 characters
);
```

**Performance**: Uses ivfflat index for fast approximate nearest neighbor search

---

### Function: `get_page_parents()`

**Purpose**: Recursively retrieve all parent pages in the hierarchy

**Signature**:
```sql
CREATE FUNCTION get_page_parents(page_id bigint)
RETURNS TABLE (
  id bigint,
  parent_page_id bigint,
  path text,
  meta jsonb
)
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| `page_id` | `bigint` | Starting page ID |

**Returns**: Table of all ancestor pages (including the starting page)

**Algorithm**: Recursive CTE (Common Table Expression) to traverse parent relationships

**Example Usage**:
```sql
SELECT * FROM get_page_parents(5);
-- Returns: [page 5, page 3 (parent), page 1 (grandparent)]
```

---

## 🔒 Row Level Security (RLS)

### Current Policies

| Table | Policy | Role | Operation | Condition |
|-------|--------|------|-----------|-----------|
| `nods_page` | `Allow all for service_role` | `service_role` | ALL | `true` |
| `nods_page_section` | `Allow all for service_role` | `service_role` | ALL | `true` |

### Policy Details

**Service Role Access** (Server-side only):
- Full read/write access to both tables
- Used by embeddings generation script
- Used by API routes for search

**Anon Role Access** (Browser/Public):
- Currently: NO ACCESS (RLS blocks all operations)
- Recommended: Add read-only policies for public search

### Recommended Public Policies

```sql
-- Allow public read access to pages
CREATE POLICY "Allow public read on nods_page"
ON nods_page FOR SELECT
TO anon
USING (true);

-- Allow public read access to page sections
CREATE POLICY "Allow public read on nods_page_section"
ON nods_page_section FOR SELECT
TO anon
USING (true);
```

---

## 🎯 Indexes & Performance

### Existing Indexes

| Index | Table | Column | Type | Purpose |
|-------|-------|--------|------|---------|
| `nods_page_pkey` | `nods_page` | `id` | B-tree | Primary key |
| `nods_page_path_key` | `nods_page` | `path` | B-tree | Unique constraint |
| `nods_page_section_pkey` | `nods_page_section` | `id` | B-tree | Primary key |
| `nods_page_section_page_id_fkey` | `nods_page_section` | `page_id` | B-tree | Foreign key |
| **Vector index** (recommended) | `nods_page_section` | `embedding` | ivfflat | Similarity search |

### Creating Vector Index

```sql
-- Create ivfflat index for fast similarity search
CREATE INDEX nods_page_section_embedding_idx
ON nods_page_section
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);
```

**Performance Impact**:
- Without index: O(n) linear scan (slow)
- With ivfflat: O(log n) approximate search (fast)
- Recommended for >1000 vectors

---

## 📈 Data Statistics

### Current Database State

| Metric | Value |
|--------|-------|
| **Pages** | 1 |
| **Page Sections** | 2 |
| **Total Embeddings** | 2 |
| **Vector Dimensions** | 1536 |
| **Database Size** | ~50MB (with extensions) |
| **Embedding Storage** | ~12KB per vector |

---

## 🔄 Data Flow & Lifecycle

### Embeddings Generation (Build Time)

```
1. Read .mdx files from pages/
   ↓
2. Parse content and split into sections
   ↓
3. Generate checksum for change detection
   ↓
4. Create/update nods_page record
   ↓
5. For each section:
   - Generate OpenAI embedding
   - Store in nods_page_section
   ↓
6. Commit to database
```

### Search Query (Runtime)

```
1. User submits query
   ↓
2. Generate query embedding (OpenAI)
   ↓
3. Call match_page_sections() function
   ↓
4. Return top N similar sections
   ↓
5. Use as context for GPT completion
```

---

## 🛠️ Maintenance Operations

### Regenerate All Embeddings

```bash
pnpm run embeddings:refresh
```

### Check Database Health

```sql
-- Count pages
SELECT COUNT(*) FROM nods_page;

-- Count sections with embeddings
SELECT COUNT(*) FROM nods_page_section WHERE embedding IS NOT NULL;

-- Check for orphaned sections
SELECT COUNT(*) FROM nods_page_section ps
LEFT JOIN nods_page p ON ps.page_id = p.id
WHERE p.id IS NULL;

-- Verify vector dimensions
SELECT id, array_length(embedding, 1) AS dimensions
FROM nods_page_section
WHERE array_length(embedding, 1) != 1536;
```

### Vacuum & Analyze

```sql
-- Optimize table storage
VACUUM ANALYZE nods_page;
VACUUM ANALYZE nods_page_section;
```

---

## 🔐 Security Considerations

### API Key Security
- ✅ Service role key stored securely in environment variables
- ✅ Never exposed to client-side code
- ✅ Used only in server-side API routes

### RLS Best Practices
- ✅ RLS enabled on all tables
- ✅ Service role has full access
- ⚠️ Public read policies needed for browser-based search

### Data Validation
- ✅ Foreign key constraints prevent orphaned records
- ✅ Unique constraint on `path` prevents duplicates
- ✅ Cascade delete ensures referential integrity

---

## 📞 Database Access

### Supabase Dashboard
- **URL**: https://app.supabase.com/project/xkxyvboeubffxxbebsll
- **Database**: `postgres`
- **Region**: US East (Ohio)

### Direct Connection (psql)
```bash
PGPASSWORD="..." psql "postgres://postgres.xkxyvboeubffxxbebsll@aws-1-us-east-1.pooler.supabase.com:5432/postgres?sslmode=require"
```

### Connection Pooler
- **Pooling**: PgBouncer (transaction mode)
- **Pool Size**: Auto-scaling
- **Max Connections**: 15 (default)

---

## 🎯 Schema Evolution

### Version History

| Version | Date | Changes |
|---------|------|---------|
| `20230406025118_init` | 2023-04-06 | Initial schema with pgvector |

### Future Enhancements

- [ ] Add `created_at` and `updated_at` timestamps
- [ ] Add `version` column for content versioning
- [ ] Add full-text search indexes
- [ ] Add analytics tables for usage tracking
- [ ] Add user tables for authentication

---

**Last Updated**: 2025-10-06
**Schema Version**: 20230406025118_init
**PostgreSQL Version**: 15.x with pgvector extension
