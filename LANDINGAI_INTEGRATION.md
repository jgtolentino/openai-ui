# LandingAI OCR Integration

This project integrates [LandingAI's Agentic Document Extraction (ADE) API](https://docs.landing.ai) for OCR and document processing capabilities.

## Features

- **PDF Processing**: Extract text and structure from PDF documents
- **Image OCR**: Process images (PNG, JPEG, WebP) to extract text
- **Page Splitting**: Split multi-page documents into individual pages
- **Structured Output**: Get markdown, JSON chunks, and metadata
- **Edge Runtime**: Fast processing with Next.js Edge Functions

## Setup

### 1. Get Your API Key

1. Sign up at [LandingAI Vision Agent](https://va.landing.ai)
2. Navigate to [Settings → API Key](https://va.landing.ai/settings/api-key)
3. Generate a new API key

### 2. Configure Environment Variables

Add to your `.env` file:

```bash
# LandingAI Configuration
LANDINGAI_API_KEY=your_api_key_here

# Optional: Use EU endpoint if needed (default is US)
LANDINGAI_API_ENDPOINT=https://api.va.landing.ai/v1
# For EU users:
# LANDINGAI_API_ENDPOINT=https://api.va.eu-west-1.landing.ai/v1
```

## Usage

### API Route

Process documents via the `/api/ocr` endpoint:

```typescript
// Upload a file
const formData = new FormData()
formData.append('file', file)
formData.append('split', 'page') // Optional: split by page
formData.append('format', 'json') // Options: json, text, markdown

const response = await fetch('/api/ocr', {
  method: 'POST',
  body: formData,
})

const result = await response.json()
// {
//   success: true,
//   data: {
//     markdown: "...",
//     chunks: [...],
//     splits: [...],
//     metadata: { pages: 5 }
//   }
// }
```

### React Component

Use the `DocumentUpload` component:

```tsx
import { DocumentUpload } from '@/components/DocumentUpload'

function MyPage() {
  return (
    <DocumentUpload
      onDocumentProcessed={(result) => {
        console.log('Extracted text:', result.markdown)
        console.log('Chunks:', result.chunks)
      }}
      onError={(error) => {
        console.error('OCR error:', error)
      }}
    />
  )
}
```

### Programmatic Usage

Use the LandingAI client directly:

```typescript
import { getLandingAIClient } from '@/lib/landingai'

// Process a file
const client = getLandingAIClient()
const result = await client.parseDocument(fileBuffer, {
  split: 'page',
})

console.log(result.markdown) // Extracted text
console.log(result.chunks) // Structured chunks
console.log(result.metadata) // Document metadata

// Process from URL
const resultFromUrl = await client.parseDocumentFromUrl(
  'https://example.com/document.pdf'
)

// Extract text only
const text = await client.extractText(fileBuffer)
```

## Integration with Document Search

### Extend Embeddings Generation

Modify `lib/generate-embeddings.ts` to process PDFs before creating embeddings:

```typescript
import { getLandingAIClient } from './landingai'

// In the processing loop
if (file.endsWith('.pdf')) {
  const client = getLandingAIClient()
  const pdfBuffer = await fs.readFile(file)
  const extracted = await client.extractText(pdfBuffer)
  // Use extracted text for embeddings
  content = extracted
}
```

### Add to Search Interface

Include document upload in the search dialog:

```tsx
import { DocumentUpload } from '@/components/DocumentUpload'

// In SearchDialog component
<DocumentUpload
  onDocumentProcessed={async (result) => {
    // Process OCR result and add to knowledge base
    await fetch('/api/process-document', {
      method: 'POST',
      body: JSON.stringify(result),
    })
  }}
/>
```

## API Reference

### LandingAIClient

#### `parseDocument(file, options)`

Process a document and extract structured data.

**Parameters:**
- `file`: Buffer or Blob - The document to process
- `options`: Object (optional)
  - `model`: string - Specific model version
  - `split`: 'page' | 'none' - Split document by page

**Returns:** Promise<ParsedDocument>

#### `parseDocumentFromUrl(url, options)`

Process a document from a URL.

**Parameters:**
- `url`: string - URL of the document
- `options`: Same as `parseDocument`

**Returns:** Promise<ParsedDocument>

#### `extractText(file)`

Extract plain text from a document.

**Parameters:**
- `file`: Buffer or Blob - The document to process

**Returns:** Promise<string>

## Supported File Types

- **PDF**: `.pdf`
- **Images**: `.png`, `.jpg`, `.jpeg`, `.webp`

## Error Handling

```typescript
try {
  const client = getLandingAIClient()
  const result = await client.parseDocument(file)
} catch (error) {
  if (error.message.includes('401')) {
    console.error('Invalid API key')
  } else if (error.message.includes('429')) {
    console.error('Rate limit exceeded')
  } else {
    console.error('Processing failed:', error.message)
  }
}
```

## Rate Limits

Check [LandingAI's pricing page](https://landing.ai/pricing) for current rate limits and quotas.

## Resources

- [LandingAI Documentation](https://docs.landing.ai)
- [API Reference](https://docs.landing.ai/api-reference/tools/ade-parse)
- [Vision Agent Platform](https://va.landing.ai)
