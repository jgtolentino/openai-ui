import fs from 'node:fs';

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) {
  console.error("Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  process.exit(2);
}

const RPC = url.replace(/\/+$/,'') + '/rest/v1/rpc/health_db_report';
const hdr = { 'apikey': key, 'Authorization': `Bearer ${key}`, 'Content-Type': 'application/json' };

const main = async () => {
  const r = await fetch(RPC, { method:'POST', headers: hdr, body: '{}' });
  if (!r.ok) {
    const txt = await r.text();
    console.error("health_db_report HTTP", r.status, txt);
    process.exit(3);
  }
  const j = await r.json();
  fs.mkdirSync('_tmp', { recursive: true });
  fs.writeFileSync('_tmp/db_report.json', JSON.stringify(j, null, 2));
  console.log("ok:", j.ok);
  if (!j.ok) {
    console.error("DB guard failed", JSON.stringify(j, null, 2));
    process.exit(1);
  }
};
main().catch(e => { console.error(e); process.exit(99); });
