/**
 * LandingAI OCR Integration
 * Provides document extraction and OCR capabilities using LandingAI's ADE API
 */

export interface LandingAIConfig {
  apiKey: string
  endpoint?: string
}

export interface ParseDocumentOptions {
  model?: string
  split?: 'page' | 'none'
}

export interface ParsedDocument {
  markdown: string
  chunks: Array<{
    text: string
    metadata?: Record<string, any>
  }>
  splits?: Array<{
    page: number
    content: string
  }>
  metadata: {
    pages?: number
    processingTime?: number
  }
}

export class LandingAIClient {
  private apiKey: string
  private endpoint: string

  constructor(config: LandingAIConfig) {
    this.apiKey = config.apiKey
    this.endpoint = config.endpoint || 'https://api.va.landing.ai/v1'
  }

  /**
   * Parse a document (PDF or image) using LandingAI's ADE API
   * @param file - File buffer or Blob to process
   * @param options - Parsing options
   * @returns Parsed document with markdown, chunks, and metadata
   */
  async parseDocument(
    file: Buffer | Blob,
    options: ParseDocumentOptions = {}
  ): Promise<ParsedDocument> {
    const formData = new FormData()

    // Add document to form data
    if (file instanceof Buffer) {
      formData.append('document', new Blob([file]))
    } else {
      formData.append('document', file)
    }

    // Add optional parameters
    if (options.model) {
      formData.append('model', options.model)
    }
    if (options.split) {
      formData.append('split', options.split)
    }

    const response = await fetch(`${this.endpoint}/ade/parse`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: formData,
    })

    if (!response.ok) {
      const error = await response.text()
      throw new Error(`LandingAI API error: ${response.status} - ${error}`)
    }

    return await response.json()
  }

  /**
   * Parse a document from a URL
   * @param url - URL of the document to process
   * @param options - Parsing options
   * @returns Parsed document with markdown, chunks, and metadata
   */
  async parseDocumentFromUrl(
    url: string,
    options: ParseDocumentOptions = {}
  ): Promise<ParsedDocument> {
    const formData = new FormData()
    formData.append('document_url', url)

    if (options.model) {
      formData.append('model', options.model)
    }
    if (options.split) {
      formData.append('split', options.split)
    }

    const response = await fetch(`${this.endpoint}/ade/parse`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: formData,
    })

    if (!response.ok) {
      const error = await response.text()
      throw new Error(`LandingAI API error: ${response.status} - ${error}`)
    }

    return await response.json()
  }

  /**
   * Extract text from a document for embedding generation
   * @param file - File buffer or Blob to process
   * @returns Plain text content
   */
  async extractText(file: Buffer | Blob): Promise<string> {
    const parsed = await this.parseDocument(file)
    return parsed.markdown
  }
}

/**
 * Get a configured LandingAI client instance
 * Uses environment variables for configuration
 */
export function getLandingAIClient(): LandingAIClient {
  const apiKey = process.env.LANDINGAI_API_KEY

  if (!apiKey) {
    throw new Error('LANDINGAI_API_KEY environment variable is not set')
  }

  return new LandingAIClient({
    apiKey,
    endpoint: process.env.LANDINGAI_API_ENDPOINT,
  })
}
