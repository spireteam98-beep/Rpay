const { pool } = require('../db');
const review = require('../services/kycReview');
const cards = require('../services/cards');
const notify = require('../services/notify');

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
        // "Request changes": the reviewer ticks the issues found (sent as
        // short labels) and/or writes a message. Both become the reason the
        // customer sees, and a chat message they can reply to.
        const issues = Array.isArray(req.body?.issues)
          ? req.body.issues.map((s) => String(s).trim().slice(0, 80)).filter(Boolean).slice(0, 8)
          : [];
        const note = String(req.body?.reason || '').trim().slice(0, 1000);
        const reason = [issues.join('; '), note].filter(Boolean).join('. ');
        if (action === 'reject' && reason.length < 3) {
          return res.status(400).json({ error: 'Pick an issue or write a message so the customer can fix it' });
        }
        // Optional: a card the reviewer scanned to hand to this customer.
        const cardUid = action === 'approve' && req.body?.cardUid ? String(req.body.cardUid) : null;
        if (cardUid && !cards.cleanUid(cardUid)) {
          return res.status(400).json({ error: 'The card could not be read. Scan it again.' });
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
        // Card and approval succeed or fail together, so a card problem
        // (already linked elsewhere, too many cards) never half-approves.
        if (cardUid) {
          const issued = await cards.issueCardToUser(client, {
            uid: cardUid, userId: req.params.userId, issuedBy: req.userId,
          });
          if (issued.error) {
            await client.query('ROLLBACK');
            return res.status(issued.error[0]).json({ error: issued.error[1], code: 'CARD_ERROR' });
          }
          result.card = { id: issued.card.id, last4: issued.card.uid.slice(-4) };
        }
        await client.query('COMMIT');
        if (action === 'approve') {
          notify.notifyUser(req.params.userId, {
            kind: 'account',
            title: 'Your Fareenn account is approved',
            body: `Your Fareenn ID is ${result.walletNumber}. Share it to receive money.`
              + (result.card ? ` Your Fareenn card •••• ${result.card.last4} is linked and ready to tap and pay.` : ''),
          });
        } else {
          // Sent as a chat message from the reviewer, so the customer can
          // reply and both sides keep talking in Messages.
          const lines = [
            'Your identity verification needs changes before it can be approved:',
            ...issues.map((i) => `• ${i}`),
            ...(note ? ['', note] : []),
            '',
            'Please fix this and submit again. Reply here if you have questions.',
          ];
          const body = lines.join('\n').slice(0, 2000);
          await pool.query(
            `INSERT INTO direct_messages (sender_id, recipient_id, body) VALUES ($1,$2,$3)`,
            [req.userId, req.params.userId, body],
          );
          notify.notifyUser(req.params.userId, {
            kind: 'message',
            title: 'Your verification needs changes',
            body,
            data: { userId: req.userId, topic: 'kyc' },
          });
          result.messageSent = true;
        }
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
