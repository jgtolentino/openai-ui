import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3001';

// Custom metrics
const expensesLatency = new Trend('expenses_latency', true);

export const options = {
  vus: 10,
  duration: '30s',
  thresholds: {
    'http_req_duration': ['p(95)<500'], // 95% of requests must complete below 500ms
    'expenses_latency': ['p(95)<300'],  // Expenses endpoint p95 < 300ms
    'http_req_failed': ['rate<0.01'],   // Error rate < 1%
  },
};

export default function () {
  // Test GET /api/v1/expenses
  const expensesRes = http.get(`${BASE_URL}/api/v1/expenses?limit=10`);

  check(expensesRes, {
    'expenses: status 200': (r) => r.status === 200,
    'expenses: has ok field': (r) => {
      try {
        return JSON.parse(r.body).ok === true;
      } catch {
        return false;
      }
    },
  });

  expensesLatency.add(expensesRes.timings.duration);

  // Test POST with idempotency key
  const submitRes = http.post(
    `${BASE_URL}/api/v1/approvals/submit`,
    JSON.stringify({ report_id: 1, actor_email: 'load-test@example.com' }),
    {
      headers: {
        'Content-Type': 'application/json',
        'Idempotency-Key': `k6-${__VU}-${__ITER}`,
      },
    }
  );

  check(submitRes, {
    'submit: not 400 idempotency error': (r) => {
      if (r.status === 400) {
        try {
          const body = JSON.parse(r.body);
          return body.error?.code !== 'IDEMPOTENCY_REQUIRED';
        } catch {
          return true;
        }
      }
      return true;
    },
  });

  sleep(0.1);
}

export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
  };
}

function textSummary(data, { indent = '', enableColors = false } = {}) {
  const colors = {
    reset: enableColors ? '\x1b[0m' : '',
    green: enableColors ? '\x1b[32m' : '',
    red: enableColors ? '\x1b[31m' : '',
    yellow: enableColors ? '\x1b[33m' : '',
  };

  const checks = data.metrics.checks;
  const httpReqDuration = data.metrics.http_req_duration;
  const httpReqFailed = data.metrics.http_req_failed;

  let summary = `${indent}${colors.green}✓${colors.reset} k6 load test summary\n`;
  summary += `${indent}  Requests: ${httpReqDuration?.values.count || 0}\n`;
  summary += `${indent}  Failed: ${(httpReqFailed?.values.rate * 100 || 0).toFixed(2)}%\n`;
  summary += `${indent}  p95: ${(httpReqDuration?.values['p(95)'] || 0).toFixed(0)}ms\n`;

  const checksPass = checks?.values.passes || 0;
  const checksFail = checks?.values.fails || 0;
  const checksRate = checksPass + checksFail > 0
    ? ((checksPass / (checksPass + checksFail)) * 100).toFixed(2)
    : 0;

  summary += `${indent}  Checks: ${checksRate}% (${checksPass}/${checksPass + checksFail})\n`;

  return summary;
}
