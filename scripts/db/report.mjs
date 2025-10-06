import fs from 'node:fs';

const HOST = (process.env.NEXT_PUBLIC_SUPABASE_URL || '').replace(/\/+$/, '');
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!HOST || !KEY) {
  console.error('Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(2);
}

const headers = {
  apikey: KEY,
  Authorization: `Bearer ${KEY}`,
  'Content-Type': 'application/json'
};

(async () => {
  const response = await fetch(`${HOST}/rest/v1/rpc/health_db_report`, {
    method: 'POST',
    headers,
    body: '{}'
  });

  if (!response.ok) {
    console.error('RPC failed', response.status, await response.text());
    process.exit(1);
  }

  const report = await response.json();

  fs.mkdirSync('_tmp', { recursive: true });
  fs.writeFileSync('_tmp/db_report.json', JSON.stringify(report, null, 2));

  console.log('Report written to _tmp/db_report.json');

  if (!report.ok) {
    console.error('DB guard FAILED');
    process.exit(1);
  }

  console.log('DB guard OK');
})().catch(e => {
  console.error(e);
  process.exit(1);
});
