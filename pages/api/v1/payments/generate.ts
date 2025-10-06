import { withContracts } from '@/lib/http/handler';
import { generatePaymentsXML } from '@/lib/services/payments';

export default withContracts({
  methods: ['POST'],
  handler: async () => await generatePaymentsXML(),
});
