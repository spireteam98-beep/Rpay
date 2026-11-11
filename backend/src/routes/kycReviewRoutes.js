const { pool } = require('../db');
const review = require('../services/kycReview');

/**
 * Adds the KYC review routes to a router. getAgent(req, client) returns the
 * reviewing agent row, or null for Fareenn HQ (admin), or undefined when the
 * caller may not review at all.
 *   GET  /kyc/pending
 *   GET  /kyc/:userId/documents
 *   POST /kyc/:userId/approve
 *   POST /kyc/:userId/reject { reason }
 */
function mountKycReview(router, getAgent) {
  router.get('/kyc/pending', async (req, res, next) => {
    try {
      const agent = await getAgent(req, pool);
      if (agent === undefined) return res.status(403).json({ error: 'Only agents can review customers' });
      res.json({ customers: await review.listPending(pool, agent) });
    } catch (err) {
      next(err);
    }
  });

  router.get('/kyc/:userId/documents', async (req, res, next) => {
    try {
      const agent = await getAgent(req, pool);
      if (agent === undefined) return res.status(403).json({ error: 'Only agents can review customers' });
      const u = (await pool.query('SELECT referred_by_agent_id FROM users WHERE id = $1', [req.params.userId])).rows[0];
      if (!u) return res.status(404).json({ error: 'Customer not found' });
      const mine = agent ? u.referred_by_agent_id === agent.id : !u.referred_by_agent_id;
      if (!mine) return res.status(403).json({ error: 'This customer is not in your review list' });
      const images = await review.documentImages(pool, req.params.userId);
      if (!images) return res.status(404).json({ error: 'No documents found' });
      res.json(images);
    } catch (err) {
      next(err);
    }
  });

  for (const action of ['approve', 'reject']) {
    router.post(`/kyc/:userId/${action}`, async (req, res, next) => {
      const client = await pool.connect();
      try {
        const agent = await getAgent(req, client);
        if (agent === undefined) return res.status(403).json({ error: 'Only agents can review customers' });
        const reason = String(req.body?.reason || '').trim();
        if (action === 'reject' && reason.length < 3) {
          return res.status(400).json({ error: 'Give the customer a reason so they can fix it' });
        }
        await client.query('BEGIN');
        const result =
          action === 'approve'
            ? await review.approve(client, agent, req.userId, req.params.userId)
            : await review.reject(client, agent, req.userId, req.params.userId, reason);
        if (result.error) {
          await client.query('ROLLBACK');
          return res.status(result.error[0]).json({ error: result.error[1] });
        }
        await client.query('COMMIT');
        res.json(result);
      } catch (err) {
        try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
        next(err);
      } finally {
        client.release();
      }
    });
  }
}

module.exports = { mountKycReview };
