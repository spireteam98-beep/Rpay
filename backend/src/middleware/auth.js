const jwt = require('jsonwebtoken');
const config = require('../config');
const { pool } = require('../db');

/**
 * Verifies "Authorization: Bearer <token>" and puts { userId } on req.
 * Also re-checks the account's current suspension status on every request —
 * a JWT stays cryptographically valid for its full 7-day life, so without
 * this an admin "suspend" would only block new logins, not a session already
 * in the user's hands.
 */
async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Missing token' });
  try {
    const payload = jwt.verify(token, config.jwtSecret);
    const result = await pool.query('SELECT status FROM users WHERE id = $1', [payload.sub]);
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    if (result.rows[0].status === 'SUSPENDED') {
      return res.status(403).json({ error: 'This account has been suspended' });
    }
    req.userId = payload.sub;
    next();
  } catch (_) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

function signToken(userId) {
  return jwt.sign({ sub: userId }, config.jwtSecret, { expiresIn: '7d' });
}

async function requireAdmin(req, res, next) {
  try {
    const result = await pool.query('SELECT role FROM users WHERE id = $1', [req.userId]);
    if (result.rows[0]?.role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }
    req.userRole = 'admin';
    next();
  } catch (err) {
    next(err);
  }
}

/**
 * Staff roles the super-admin can grant (POST /admin/users/:id/role).
 * 'admin' itself is never grantable — it's pinned to config.adminEmail.
 *   operations: approves agents, trustees' customers' KYC, businesses
 *   support:    answers issue reports / messages to Fareenn, views users
 *   compliance: AML, KYC, suspensions, all transactions
 */
const STAFF_ROLES = ['operations', 'support', 'compliance'];

/** Lets the super-admin or any staff role through; sets req.userRole. */
async function requireStaff(req, res, next) {
  try {
    const result = await pool.query('SELECT role FROM users WHERE id = $1', [req.userId]);
    const role = result.rows[0]?.role;
    if (role !== 'admin' && !STAFF_ROLES.includes(role)) {
      return res.status(403).json({ error: 'Staff access required' });
    }
    req.userRole = role;
    next();
  } catch (err) {
    next(err);
  }
}

module.exports = { requireAuth, requireAdmin, requireStaff, STAFF_ROLES, signToken };
