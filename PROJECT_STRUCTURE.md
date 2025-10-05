# Next.js OpenAI Doc Search - Complete Project Structure

## 📁 Directory Overview

```
nextjs-openai-doc-search-starter/
├── components/          # React components
│   ├── ui/             # Radix UI primitives
│   └── SearchDialog.tsx # Main search interface
├── lib/                # Core utilities
│   ├── generate-embeddings.ts  # Build-time embedding generator
│   ├── errors.ts       # Custom error classes
│   └── utils.ts        # Utility functions
├── pages/              # Next.js pages & API
│   ├── api/
│   │   └── vector-search.ts  # Runtime vector search endpoint
│   ├── docs/
│   │   └── openai_embeddings.mdx  # Example documentation
│   ├── _app.tsx        # App wrapper
│   ├── _document.tsx   # HTML document structure
│   └── index.tsx       # Home page with search UI
├── public/             # Static assets
├── styles/             # CSS styles
├── supabase/           # Supabase configuration
│   ├── migrations/
│   │   └── 20230406025118_init.sql  # Database schema
│   ├── config.toml     # Local Supabase config
│   └── seed.sql        # Seed data
├── types/              # TypeScript type definitions
└── [config files]      # package.json, tsconfig.json, etc.
```

## 🏗️ Architecture

### Build Time (Embedding Generation)

**File**: `lib/generate-embeddings.ts`

**Process**:
1. Scans all `.mdx` files in `pages/` directory
2. Processes each file:
   - Extracts metadata (frontmatter)
   - Strips JSX elements
   - Splits into sections by headings
   - Generates SHA256 checksum
3. Creates embeddings via OpenAI API:
   - Model: `text-embedding-ada-002`
   - Vector dimension: 1536
4. Stores in Supabase:
   - Table: `nods_page` (page metadata)
   - Table: `nods_page_section` (sections with embeddings)
5. Checksum-based caching (only regenerates changed files)

**Key Features**:
- Incremental updates (checksums)
- Parent-child page relationships
- MDX metadata extraction
- Section-level embeddings

### Runtime (Vector Search)

**File**: `pages/api/vector-search.ts`

**Process**:
1. **Input**: User query
2. **Moderation**: OpenAI content moderation check
3. **Query Embedding**: Generate embedding for query
4. **Vector Search**: Match against stored embeddings
   - Function: `match_page_sections()`
   - Threshold: 0.78 similarity
   - Top 10 matches
   - Min content length: 50 chars
5. **Context Building**: Aggregate matched sections (max 1500 tokens)
6. **Completion**: Stream GPT-3.5-turbo response
   - Model: `gpt-3.5-turbo`
   - Max tokens: 512
   - Temperature: 0 (deterministic)

**Edge Function**: Deployed on Vercel Edge Runtime for low latency

## 🗄️ Database Schema

### Tables

**`nods_page`**
```sql
- id (bigserial, PK)
- parent_page_id (bigint, FK to nods_page)
- path (text, unique) - URL path
- checksum (text) - SHA256 of content
- meta (jsonb) - Frontmatter metadata
- type (text) - Content type
- source (text) - Source identifier
```

**`nods_page_section`**
```sql
- id (bigserial, PK)
- page_id (bigint, FK to nods_page)
- content (text) - Section text
- token_count (int) - OpenAI tokens
- embedding (vector(1536)) - OpenAI embedding
- slug (text) - URL fragment
- heading (text) - Section heading
```

### Functions

**`match_page_sections(embedding, match_threshold, match_count, min_content_length)`**
- Vector similarity search using pgvector
- Cosine similarity via dot product
- Filters by content length and similarity threshold
- Returns top N matches ordered by similarity

**`get_page_parents(page_id)`**
- Recursive CTE for page hierarchy
- Returns all parent pages

## 🎨 Frontend Components

### SearchDialog.tsx
- **UI Framework**: Radix UI primitives
- **Features**:
  - Command palette interface
  - Keyboard shortcuts (Cmd+K)
  - Streaming responses
  - Markdown rendering
- **API Integration**: Calls `/api/vector-search`

### UI Components (Radix UI)
- `button.tsx` - Button primitive
- `command.tsx` - Command palette
- `dialog.tsx` - Modal dialog
- `input.tsx` - Text input
- `label.tsx` - Form label

## 🔧 Configuration Files

### Environment Variables
```bash
# Supabase
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# OpenAI
OPENAI_KEY=
```

### package.json Scripts
```json
{
  "dev": "next dev",
  "build": "pnpm run embeddings && next build",
  "start": "next start",
  "embeddings": "tsx lib/generate-embeddings.ts",
  "embeddings:refresh": "tsx lib/generate-embeddings.ts --refresh"
}
```

## 📦 Key Dependencies

### Production
- **Next.js 13.2.4** - React framework
- **@supabase/supabase-js 2.13.0** - Supabase client
- **openai 3.3.0** - OpenAI Node SDK (build time)
- **openai-edge 1.1.0** - OpenAI Edge SDK (runtime)
- **ai 2.1.3** - Vercel AI SDK (streaming)
- **Radix UI** - Accessible components
- **Tailwind CSS** - Styling

### Dev Dependencies
- **TypeScript 4.9.5**
- **tsx 3.12.6** - TypeScript executor
- **dotenv 16.0.3** - Environment variables
- **prettier 2.8.7** - Code formatting

## 🚀 Deployment Flow

### 1. Vercel Deployment
- Auto-detects Next.js
- Runs `pnpm run build`
  - Executes `pnpm run embeddings` first
  - Then `next build`

### 2. Supabase Integration
- Vercel marketplace integration
- Auto-sets environment variables:
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY`
- Applies migrations automatically

### 3. Required Manual Steps
- Set `OPENAI_KEY` in Vercel dashboard
- Ensure `.mdx` files exist in `pages/` directory
- Share Supabase tables with integration

## 🔐 Security Model

### Build Time
- Uses `SUPABASE_SERVICE_ROLE_KEY` (admin access)
- Direct database writes

### Runtime
- Uses `NEXT_PUBLIC_SUPABASE_ANON_KEY` (public access)
- Row Level Security (RLS) enabled
- Content moderation via OpenAI

## 📊 Data Flow

### Build Time
```
.mdx files → processMdxForSearch() → OpenAI embeddings API → Supabase (nods_page + nods_page_section)
```

### Runtime
```
User query → OpenAI embeddings API → pgvector similarity search → Context aggregation → GPT-3.5-turbo → Streaming response
```

## 🎯 Production Checklist

- [ ] Supabase project created
- [ ] Vercel project created
- [ ] Environment variables set:
  - [ ] `OPENAI_KEY`
  - [ ] `NEXT_PUBLIC_SUPABASE_URL`
  - [ ] `NEXT_PUBLIC_SUPABASE_ANON_KEY`
  - [ ] `SUPABASE_SERVICE_ROLE_KEY`
- [ ] Database migrations applied
- [ ] `.mdx` documentation files added
- [ ] Initial build completed (embeddings generated)
- [ ] Edge function deployed
- [ ] Search functionality tested

## 📝 Customization Points

1. **Documentation Content**: Replace `.mdx` files in `pages/docs/`
2. **Branding**: Update system prompt in `vector-search.ts` (line 114-122)
3. **Search Parameters**:
   - `match_threshold`: Similarity threshold (default: 0.78)
   - `match_count`: Top N results (default: 10)
   - `max_tokens`: Response length (default: 512)
4. **UI Components**: Customize Radix UI components in `components/ui/`
5. **Styling**: Modify Tailwind config and global styles

## 🔗 External Resources

- [Supabase pgvector docs](https://supabase.com/docs/guides/database/extensions/pgvector)
- [OpenAI Embeddings](https://platform.openai.com/docs/guides/embeddings)
- [Vercel AI SDK](https://sdk.vercel.ai/docs)
- [Original blog post](https://supabase.com/blog/chatgpt-supabase-docs)
