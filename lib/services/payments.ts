import { generatePain001 } from '@/lib/payments/pain001';

export async function generatePaymentsXML() {
  // Assuming existing helpers resolve unpaid reimbursements
  const xml = await generatePain001({});
  return { preview: xml.slice(0, 2048) };
}
