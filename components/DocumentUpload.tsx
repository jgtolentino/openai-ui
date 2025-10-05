import { useState, useRef } from 'react'
import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'

interface DocumentUploadProps {
  onDocumentProcessed?: (result: any) => void
  onError?: (error: string) => void
}

export function DocumentUpload({
  onDocumentProcessed,
  onError,
}: DocumentUploadProps) {
  const [isProcessing, setIsProcessing] = useState(false)
  const [result, setResult] = useState<any>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const handleFileUpload = async (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    const file = event.target.files?.[0]
    if (!file) return

    setIsProcessing(true)
    setResult(null)

    try {
      const formData = new FormData()
      formData.append('file', file)
      formData.append('split', 'page')

      const response = await fetch('/api/ocr', {
        method: 'POST',
        body: formData,
      })

      if (!response.ok) {
        const error = await response.json()
        throw new Error(error.details || 'Failed to process document')
      }

      const data = await response.json()
      setResult(data.data)
      onDocumentProcessed?.(data.data)
    } catch (err) {
      const errorMessage =
        err instanceof Error ? err.message : 'Unknown error occurred'
      console.error('Upload error:', errorMessage)
      onError?.(errorMessage)
    } finally {
      setIsProcessing(false)
    }
  }

  const handleButtonClick = () => {
    fileInputRef.current?.click()
  }

  return (
    <div className="space-y-4">
      <div>
        <Label htmlFor="document-upload" className="sr-only">
          Upload Document
        </Label>
        <input
          ref={fileInputRef}
          id="document-upload"
          type="file"
          accept=".pdf,.png,.jpg,.jpeg,.webp"
          onChange={handleFileUpload}
          className="hidden"
        />
        <Button
          onClick={handleButtonClick}
          disabled={isProcessing}
          variant="outline"
          className="w-full"
        >
          {isProcessing ? 'Processing...' : 'Upload Document (PDF/Image)'}
        </Button>
      </div>

      {result && (
        <div className="border rounded-lg p-4 space-y-2">
          <h3 className="font-semibold">Extracted Content:</h3>
          <div className="bg-muted p-3 rounded text-sm max-h-96 overflow-y-auto">
            <pre className="whitespace-pre-wrap">{result.markdown}</pre>
          </div>
          {result.metadata && (
            <div className="text-xs text-muted-foreground">
              {result.metadata.pages && (
                <span>Pages: {result.metadata.pages} • </span>
              )}
              {result.chunks && (
                <span>Chunks: {result.chunks.length}</span>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
