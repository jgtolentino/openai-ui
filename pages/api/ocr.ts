import { NextRequest, NextResponse } from 'next/server'
import { getLandingAIClient } from '@/lib/landingai'

export const config = {
  runtime: 'edge',
}

/**
 * API Route: /api/ocr
 * Process documents (PDFs, images) using LandingAI OCR
 *
 * Methods:
 * - POST: Upload and process a document
 *
 * Request Body (multipart/form-data):
 * - file: Document file (PDF, image)
 * - split: Optional - 'page' to split by page
 * - format: Optional - 'text' | 'markdown' | 'json' (default: json)
 *
 * Response:
 * - 200: Processed document data
 * - 400: Bad request
 * - 500: Server error
 */
export default async function handler(req: NextRequest) {
  if (req.method !== 'POST') {
    return NextResponse.json(
      { error: 'Method not allowed' },
      { status: 405 }
    )
  }

  try {
    const formData = await req.formData()
    const file = formData.get('file') as File
    const split = formData.get('split') as string | null
    const format = (formData.get('format') as string) || 'json'

    if (!file) {
      return NextResponse.json(
        { error: 'No file provided' },
        { status: 400 }
      )
    }

    // Validate file type
    const allowedTypes = [
      'application/pdf',
      'image/png',
      'image/jpeg',
      'image/jpg',
      'image/webp',
    ]

    if (!allowedTypes.includes(file.type)) {
      return NextResponse.json(
        {
          error: 'Invalid file type. Supported: PDF, PNG, JPEG, WebP',
        },
        { status: 400 }
      )
    }

    // Process with LandingAI
    const client = getLandingAIClient()
    const arrayBuffer = await file.arrayBuffer()
    const buffer = Buffer.from(arrayBuffer)

    const result = await client.parseDocument(buffer, {
      split: split === 'page' ? 'page' : undefined,
    })

    // Return in requested format
    if (format === 'text') {
      return new NextResponse(result.markdown, {
        headers: { 'Content-Type': 'text/plain' },
      })
    }

    if (format === 'markdown') {
      return new NextResponse(result.markdown, {
        headers: { 'Content-Type': 'text/markdown' },
      })
    }

    // Default: JSON
    return NextResponse.json({
      success: true,
      data: result,
    })
  } catch (error) {
    console.error('OCR processing error:', error)

    return NextResponse.json(
      {
        error: 'Failed to process document',
        details: error instanceof Error ? error.message : 'Unknown error',
      },
      { status: 500 }
    )
  }
}
