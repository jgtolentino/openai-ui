import { withContracts } from '@/lib/http/handler';
import { summary } from '@/lib/services/analytics';

export default withContracts({
  methods: ['GET'],
  requireIdempotency: false,
  handler: summary,
});
