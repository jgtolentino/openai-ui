import { test, expect } from '@playwright/test'

const BASE_URL = process.env.BASE_URL || 'http://localhost:3001'

test.describe('API v1 Conformance', () => {
  test('GET /api/v1/expenses returns DTO envelope', async ({ request }) => {
    const response = await request.get(`${BASE_URL}/api/v1/expenses?limit=5`)
    expect(response.status()).toBe(200)

    const body = await response.json()
    expect(body).toHaveProperty('ok')
    expect(body.ok).toBe(true)
    expect(body).toHaveProperty('data')
    expect(Array.isArray(body.data)).toBe(true)
  })

  test('POST without Idempotency-Key is rejected', async ({ request }) => {
    const response = await request.post(`${BASE_URL}/api/v1/approvals/submit`, {
      data: { report_id: 1, actor_email: 'test@example.com' },
    })

    expect(response.status()).toBe(400)
    const body = await response.json()
    expect(body.ok).toBe(false)
    expect(body.error.code).toBe('IDEMPOTENCY_REQUIRED')
  })

  test('POST with Idempotency-Key succeeds', async ({ request }) => {
    const response = await request.post(`${BASE_URL}/api/v1/approvals/submit`, {
      data: { report_id: 1, actor_email: 'test@example.com' },
      headers: { 'Idempotency-Key': 'test-key-' + Date.now() },
    })

    // May succeed or fail based on data, but should not be 400 IDEMPOTENCY_REQUIRED
    expect(response.status()).not.toBe(400)
    const body = await response.json()
    expect(body).toHaveProperty('ok')
  })

  test('DTO error envelope format', async ({ request }) => {
    const response = await request.get(`${BASE_URL}/api/v1/nonexistent`)
    expect(response.status()).toBeGreaterThanOrEqual(400)

    const body = await response.json()
    if (body.ok === false) {
      expect(body).toHaveProperty('error')
      expect(body.error).toHaveProperty('code')
      expect(body.error).toHaveProperty('message')
    }
  })

  test('GET endpoints cache headers', async ({ request }) => {
    const response = await request.get(`${BASE_URL}/api/v1/expenses?limit=1`)
    expect(response.status()).toBe(200)

    const cacheControl = response.headers()['cache-control']
    expect(cacheControl).toBeTruthy()
  })
})
