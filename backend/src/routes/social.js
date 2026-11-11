const express = require('express');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const notify = require('../services/notify');
const { resolveUserByIdentifier, publicProfile } = require('../services/users');

/**
 * Fareenn social layer: find people, follow them, message them, and reach
 * Fareenn itself (messages + issue reports, answered by support staff in the
 * Admin Portal). Every "who" here accepts a user id OR any identifier the
 * person hands out — email, phone, @username or Fareenn ID.
 */
const router = express.Router();
router.use(requireAuth);

const PROFILE_COLUMNS = `u.id, u.full_name, u.username, u.wallet_number, u.avatar_url,
  (SELECT a.tier FROM agents a WHERE a.user_id = u.id AND a.status = 'ACTIVE' LIMIT 1) AS agent_tier`;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Accepts a user id or any identifier; returns an ACTIVE, non-deleted user or null. */
async function findTarget(db, who) {
  const value = String(who || '').trim();
  if (!value) return null;
  if (UUID_RE.test(value)) {
    const row = (
      await db.query(
        `SELECT id, full_name, status FROM users WHERE id = $1 AND deletion_requested_at IS NULL`,
        [value],
      )
    ).rows[0];
    if (row) return row.status === 'SUSPENDED' ? null : row;
  }
  const row = await resolveUserByIdentifier(db, value, 'id, full_name, status');
  return row && row.status !== 'SUSPENDED' ? row : null;
}

function trimBody(value, max) {
  const body = String(value || '').trim();
  return body && body.length <= max ? body : null;
}

// ── Search & profiles ─────────────────────────────────────────────────────

/**
 * GET /social/search?q= — name / @username prefix match, or an exact
 * email, phone or Fareenn ID. Never returns email/phone/balances, so search
 * can't be used to harvest contact details.
 */
router.get('/search', async (req, res, next) => {
  try {
    const raw = String(req.query.q || '').trim();
    if (raw.length < 2) return res.json([]);
    const q = raw.replace(/^@/, '').toLowerCase().replace(/[\\%_]/g, '');
    if (!q) return res.json([]);
    const rows = await pool.query(
      `SELECT ${PROFILE_COLUMNS},
              EXISTS (SELECT 1 FROM follows f WHERE f.follower_id = $3 AND f.followee_id = u.id) AS is_following
         FROM users u
        WHERE u.id <> $3 AND u.status = 'ACTIVE' AND u.deletion_requested_at IS NULL
          AND (LOWER(u.username) LIKE $1 || '%'
               OR LOWER(u.full_name) LIKE '%' || $1 || '%'
               OR LOWER(u.email) = $2 OR u.phone = $4 OR u.wallet_number = $4)
        ORDER BY (LOWER(u.username) = $1 OR u.wallet_number = $4) DESC, u.full_name
        LIMIT 25`,
      [q, raw.toLowerCase(), req.userId, raw],
    );
    res.json(rows.rows.map((r) => ({ ...publicProfile(r), isFollowing: r.is_following })));
  } catch (err) {
    next(err);
  }
});

/** GET /social/users/:who — public profile + follow counts. */
router.get('/users/:who', async (req, res, next) => {
  try {
    const target = await findTarget(pool, req.params.who);
    if (!target) return res.status(404).json({ error: 'User not found' });
    const row = (
      await pool.query(
        `SELECT ${PROFILE_COLUMNS},
                (SELECT COUNT(*)::int FROM follows WHERE followee_id = u.id) AS followers,
                (SELECT COUNT(*)::int FROM follows WHERE follower_id = u.id) AS following,
                EXISTS (SELECT 1 FROM follows f WHERE f.follower_id = $2 AND f.followee_id = u.id) AS is_following
           FROM users u WHERE u.id = $1`,
        [target.id, req.userId],
      )
    ).rows[0];
    res.json({
      ...publicProfile(row),
      followers: row.followers,
      following: row.following,
      isFollowing: row.is_following,
      isMe: row.id === req.userId,
    });
  } catch (err) {
    next(err);
  }
});

// ── Follow ────────────────────────────────────────────────────────────────

router.post('/follow/:who', async (req, res, next) => {
  try {
    const target = await findTarget(pool, req.params.who);
    if (!target) return res.status(404).json({ error: 'User not found' });
    if (target.id === req.userId) return res.status(400).json({ error: "You can't follow yourself" });
    const inserted = await pool.query(
      `INSERT INTO follows (follower_id, followee_id) VALUES ($1,$2)
       ON CONFLICT DO NOTHING RETURNING follower_id`,
      [req.userId, target.id],
    );
    if (inserted.rows.length) {
      const me = (await pool.query('SELECT full_name FROM users WHERE id = $1', [req.userId])).rows[0];
      notify.notifyUser(target.id, {
        kind: 'follow',
        title: 'New follower',
        body: `${me?.full_name || 'Someone'} started following you on Fareenn`,
        data: { userId: req.userId },
      });
    }
    res.json({ following: true });
  } catch (err) {
    next(err);
  }
});

router.delete('/follow/:who', async (req, res, next) => {
  try {
    const target = await findTarget(pool, req.params.who);
    if (!target) return res.status(404).json({ error: 'User not found' });
    await pool.query('DELETE FROM follows WHERE follower_id = $1 AND followee_id = $2', [req.userId, target.id]);
    res.json({ following: false });
  } catch (err) {
    next(err);
  }
});

/** GET /social/following and /social/followers — the caller's own lists. */
for (const [path, mine, theirs] of [
  ['/following', 'follower_id', 'followee_id'],
  ['/followers', 'followee_id', 'follower_id'],
]) {
  router.get(path, async (req, res, next) => {
    try {
      const rows = await pool.query(
        `SELECT ${PROFILE_COLUMNS},
                EXISTS (SELECT 1 FROM follows x WHERE x.follower_id = $1 AND x.followee_id = u.id) AS is_following
           FROM follows f JOIN users u ON u.id = f.${theirs}
          WHERE f.${mine} = $1 AND u.status = 'ACTIVE'
          ORDER BY f.created_at DESC
          LIMIT 500`,
        [req.userId],
      );
      res.json(rows.rows.map((r) => ({ ...publicProfile(r), isFollowing: r.is_following })));
    } catch (err) {
      next(err);
    }
  });
}

/**
 * GET /social/contacts — quick-reach list for the profile menu: the agent
 * or trustee who onboarded me, the people I follow, and Fareenn support.
 */
router.get('/contacts', async (req, res, next) => {
  try {
    const [myAgent, following] = await Promise.all([
      pool.query(
        `SELECT ${PROFILE_COLUMNS}, a.business_name, a.agent_code
           FROM users me
           JOIN agents a ON a.id = me.referred_by_agent_id
           JOIN users u ON u.id = a.user_id
          WHERE me.id = $1`,
        [req.userId],
      ),
      pool.query(
        `SELECT ${PROFILE_COLUMNS}
           FROM follows f JOIN users u ON u.id = f.followee_id
          WHERE f.follower_id = $1 AND u.status = 'ACTIVE'
          ORDER BY f.created_at DESC LIMIT 100`,
        [req.userId],
      ),
    ]);
    const agentRow = myAgent.rows[0];
    res.json({
      myAgent: agentRow
        ? { ...publicProfile(agentRow), businessName: agentRow.business_name, agentCode: agentRow.agent_code }
        : null,
      following: following.rows.map(publicProfile),
      fareenn: { name: 'Fareenn Support', canMessage: true, canReportIssue: true },
    });
  } catch (err) {
    next(err);
  }
});

// ── Direct messages ───────────────────────────────────────────────────────

/** GET /social/conversations — latest message per person + unread count. */
router.get('/conversations', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `WITH mine AS (
         SELECT m.*, CASE WHEN m.sender_id = $1 THEN m.recipient_id ELSE m.sender_id END AS other_id
           FROM direct_messages m
          WHERE m.sender_id = $1 OR m.recipient_id = $1
       ), latest AS (
         SELECT DISTINCT ON (other_id) * FROM mine ORDER BY other_id, created_at DESC
       )
       SELECT l.other_id, l.body AS last_body, l.created_at AS last_at, (l.sender_id = $1) AS last_from_me,
              (SELECT COUNT(*)::int FROM mine x
                WHERE x.other_id = l.other_id AND x.recipient_id = $1 AND x.read_at IS NULL) AS unread,
              ${PROFILE_COLUMNS}
         FROM latest l JOIN users u ON u.id = l.other_id
        ORDER BY l.created_at DESC
        LIMIT 200`,
      [req.userId],
    );
    res.json(
      rows.rows.map((r) => ({
        user: publicProfile(r),
        lastBody: r.last_body,
        lastAt: r.last_at,
        lastFromMe: r.last_from_me,
        unread: r.unread,
      })),
    );
  } catch (err) {
    next(err);
  }
});

/** GET /social/messages/:who — the thread with one person (marks it read). */
router.get('/messages/:who', async (req, res, next) => {
  try {
    const target = await findTarget(pool, req.params.who);
    if (!target) return res.status(404).json({ error: 'User not found' });
    const rows = await pool.query(
      `SELECT id, sender_id, recipient_id, body, read_at, created_at, (sender_id = $1) AS from_me
         FROM direct_messages
        WHERE (sender_id = $1 AND recipient_id = $2) OR (sender_id = $2 AND recipient_id = $1)
        ORDER BY created_at DESC
        LIMIT 200`,
      [req.userId, target.id],
    );
    await pool.query(
      `UPDATE direct_messages SET read_at = now()
        WHERE sender_id = $1 AND recipient_id = $2 AND read_at IS NULL`,
      [target.id, req.userId],
    );
    res.json({ with: { id: target.id, fullName: target.full_name }, messages: rows.rows.reverse() });
  } catch (err) {
    next(err);
  }
});

/** POST /social/messages { to, body } — `to` is a user id or any identifier. */
router.post('/messages', async (req, res, next) => {
  try {
    const body = trimBody(req.body?.body, 2000);
    if (!body) return res.status(400).json({ error: 'Message must be 1-2000 characters' });
    const target = await findTarget(pool, req.body?.to);
    if (!target) {
      return res.status(404).json({ error: 'No Fareenn user found with that email, phone, @username or Fareenn ID' });
    }
    if (target.id === req.userId) return res.status(400).json({ error: "You can't message yourself" });
    const message = (
      await pool.query(
        `INSERT INTO direct_messages (sender_id, recipient_id, body) VALUES ($1,$2,$3)
         RETURNING id, sender_id, recipient_id, body, read_at, created_at, TRUE AS from_me`,
        [req.userId, target.id, body],
      )
    ).rows[0];
    const me = (await pool.query('SELECT full_name FROM users WHERE id = $1', [req.userId])).rows[0];
    notify.notifyUser(target.id, {
      kind: 'message',
      title: `Message from ${me?.full_name || 'a Fareenn user'}`,
      body: body.length > 140 ? `${body.slice(0, 137)}...` : body,
      data: { userId: req.userId },
    });
    res.status(201).json({ message, to: { id: target.id, fullName: target.full_name } });
  } catch (err) {
    next(err);
  }
});

// ── Messages to Fareenn & issue reports ───────────────────────────────────

const ISSUE_CATEGORIES = ['payment', 'transfer', 'card', 'account', 'agent', 'fraud', 'app', 'other'];

/**
 * POST /social/support { kind: 'message'|'issue', subject?, category?, body }
 * — opens a ticket that support staff answer from the Admin Portal.
 */
router.post('/support', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const kind = req.body?.kind === 'issue' ? 'issue' : 'message';
    const body = trimBody(req.body?.body, 4000);
    if (!body) return res.status(400).json({ error: 'Describe it in 1-4000 characters' });
    const category = kind === 'issue'
      ? (ISSUE_CATEGORIES.includes(req.body?.category) ? req.body.category : 'other')
      : null;
    const subject = trimBody(req.body?.subject, 140)
      || (kind === 'issue' ? `Issue: ${category}` : body.slice(0, 80));

    await client.query('BEGIN');
    const ticket = (
      await client.query(
        `INSERT INTO support_tickets (user_id, kind, category, subject) VALUES ($1,$2,$3,$4) RETURNING *`,
        [req.userId, kind, category, subject],
      )
    ).rows[0];
    await client.query(
      `INSERT INTO support_ticket_messages (ticket_id, sender_id, from_staff, body) VALUES ($1,$2,FALSE,$3)`,
      [ticket.id, req.userId, body],
    );
    await client.query('COMMIT');
    notify.notifyUser(req.userId, {
      kind: 'support',
      title: kind === 'issue' ? 'Issue reported' : 'Message sent to Fareenn',
      body: 'Fareenn support will reply here. You will get a notification when they do.',
      data: { ticketId: ticket.id },
    });
    res.status(201).json({ ticket });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** GET /social/support — my tickets. */
router.get('/support', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT t.*, (SELECT body FROM support_ticket_messages m WHERE m.ticket_id = t.id
                     ORDER BY created_at DESC LIMIT 1) AS last_message
         FROM support_tickets t WHERE t.user_id = $1
        ORDER BY t.updated_at DESC LIMIT 100`,
      [req.userId],
    );
    res.json(rows.rows);
  } catch (err) {
    next(err);
  }
});

/** GET /social/support/:id — one of my tickets with its thread. */
router.get('/support/:id', async (req, res, next) => {
  try {
    const ticket = (
      await pool.query('SELECT * FROM support_tickets WHERE id = $1 AND user_id = $2', [req.params.id, req.userId])
    ).rows[0];
    if (!ticket) return res.status(404).json({ error: 'Ticket not found' });
    const messages = await pool.query(
      `SELECT id, body, from_staff, created_at,
              CASE WHEN from_staff THEN 'Fareenn Support' ELSE 'You' END AS sender_name
         FROM support_ticket_messages WHERE ticket_id = $1 ORDER BY created_at`,
      [ticket.id],
    );
    res.json({ ticket, messages: messages.rows });
  } catch (err) {
    next(err);
  }
});

/** POST /social/support/:id/reply { body } — add to my own ticket (reopens it). */
router.post('/support/:id/reply', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const body = trimBody(req.body?.body, 4000);
    if (!body) return res.status(400).json({ error: 'Message must be 1-4000 characters' });
    await client.query('BEGIN');
    const ticket = (
      await client.query(
        `UPDATE support_tickets SET status = 'OPEN', updated_at = now()
          WHERE id = $1 AND user_id = $2 RETURNING *`,
        [req.params.id, req.userId],
      )
    ).rows[0];
    if (!ticket) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Ticket not found' });
    }
    const message = (
      await client.query(
        `INSERT INTO support_ticket_messages (ticket_id, sender_id, from_staff, body)
         VALUES ($1,$2,FALSE,$3) RETURNING *`,
        [ticket.id, req.userId, body],
      )
    ).rows[0];
    await client.query('COMMIT');
    res.status(201).json({ message });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

// ── Notification inbox ────────────────────────────────────────────────────

router.get('/notifications', async (req, res, next) => {
  try {
    const [items, unread] = await Promise.all([
      pool.query(
        `SELECT id, kind, title, body, data, read_at, created_at
           FROM notifications WHERE user_id = $1
          ORDER BY created_at DESC LIMIT 100`,
        [req.userId],
      ),
      pool.query(
        `SELECT
           (SELECT COUNT(*)::int FROM notifications WHERE user_id = $1 AND read_at IS NULL) AS notifications,
           (SELECT COUNT(*)::int FROM direct_messages WHERE recipient_id = $1 AND read_at IS NULL) AS messages`,
        [req.userId],
      ),
    ]);
    res.json({ unread: unread.rows[0], notifications: items.rows });
  } catch (err) {
    next(err);
  }
});

/** GET /social/unread — badge counts for the profile avatar. */
router.get('/unread', async (req, res, next) => {
  try {
    const row = (
      await pool.query(
        `SELECT
           (SELECT COUNT(*)::int FROM notifications WHERE user_id = $1 AND read_at IS NULL) AS notifications,
           (SELECT COUNT(*)::int FROM direct_messages WHERE recipient_id = $1 AND read_at IS NULL) AS messages`,
        [req.userId],
      )
    ).rows[0];
    res.json(row);
  } catch (err) {
    next(err);
  }
});

/** POST /social/notifications/read { ids? } — marks given ids, or all, as read. */
router.post('/notifications/read', async (req, res, next) => {
  try {
    const ids = Array.isArray(req.body?.ids) ? req.body.ids.filter((id) => UUID_RE.test(String(id))) : null;
    if (ids && ids.length) {
      await pool.query(
        `UPDATE notifications SET read_at = now() WHERE user_id = $1 AND id = ANY($2) AND read_at IS NULL`,
        [req.userId, ids],
      );
    } else {
      await pool.query(`UPDATE notifications SET read_at = now() WHERE user_id = $1 AND read_at IS NULL`, [req.userId]);
    }
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
