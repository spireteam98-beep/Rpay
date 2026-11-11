const crypto = require('crypto');
const express = require('express');
const bcrypt = require('bcryptjs');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const ledger = require('../services/ledger');
const config = require('../config');
const compliance = require('../services/compliance');
const notify = require('../services/notify');

/**
 * Fareenn closed-loop NFC cards (MIFARE Classic 1K test cards; NTAG also works).
 *
 * The card never holds money. It carries two things:
 *   - its factory UID (4 bytes on MIFARE Classic, 7 on NTAG), and
 *   - an NDEF URL record https://www.fareenn.com/c/<token>, where <token> is
 *     a random 128-bit value issued by this server.
 * A payment only goes through when the UID and token match an ACTIVE card
 * AND the cardholder enters their Fareenn PIN on the merchant's phone.
 * Balances stay in the wallet; the card is just a key to it.
 */
const router = express.Router();
router.use(requireAuth);

const CARD_URL = 'https://www.fareenn.com/c/';
const MAX_PIN_FAILURES = 3;
const MAX_CARDS_PER_USER = 2;

function cleanUid(value) {
  const uid = String(value || '').replace(/[^0-9a-fA-F]/g, '').toUpperCase();
  // NTAG21x UIDs are 7 bytes; allow 4–10 bytes for other chips.
  if (uid.length < 8 || uid.length > 20 || uid.length % 2) return null;
  return uid;
}

function cleanToken(value) {
  let token = String(value || '').trim();
  const at = token.indexOf('/c/');
  if (at >= 0) token = token.slice(at + 3);
  token = token.split(/[?#/]/)[0];
  return /^[A-Za-z0-9_-]{20,40}$/.test(token) ? token : null;
}

function cleanCurrency(value) {
  const currency = String(value || 'USD').toUpperCase();
  if (!['KES', 'USD'].includes(currency)) throw Object.assign(new Error('currency must be KES or USD'), { status: 400 });
  return currency;
}

function sameToken(a, b) {
  const x = Buffer.from(String(a)), y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

// Closed-loop card numbers: 9 (national-use major industry identifier) +
// 252 (Somalia) + 11 random digits + a Luhn check digit. They only work on
// the Fareenn network, never on Visa/Mastercard rails.
function luhnDigit(body) {
  let sum = 0;
  for (let i = 0; i < body.length; i += 1) {
    let d = Number(body[body.length - 1 - i]);
    if (i % 2 === 0) { d *= 2; if (d > 9) d -= 9; }
    sum += d;
  }
  return String((10 - (sum % 10)) % 10);
}
function newCardNumber() {
  let body = '9252';
  while (body.length < 15) body += String(crypto.randomInt(10));
  return body + luhnDigit(body);
}
function newExpiry() {
  const d = new Date();
  return `${String(d.getUTCMonth() + 1).padStart(2, '0')}/${String((d.getUTCFullYear() + 5) % 100).padStart(2, '0')}`;
}
const cvcKey = crypto.createHash('sha256').update(`${config.jwtSecret}:fareenn-card-cvc`).digest();
function encryptCvc(cvc) {
  const iv = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-256-gcm', cvcKey, iv);
  const enc = Buffer.concat([c.update(cvc, 'utf8'), c.final()]);
  return [iv, c.getAuthTag(), enc].map((b) => b.toString('base64')).join('.');
}
function decryptCvc(value) {
  const [iv, tag, enc] = String(value).split('.').map((s) => Buffer.from(s, 'base64'));
  const d = crypto.createDecipheriv('aes-256-gcm', cvcKey, iv);
  d.setAuthTag(tag);
  return Buffer.concat([d.update(enc), d.final()]).toString('utf8');
}
async function uniqueCardNumber(client) {
  for (let i = 0; i < 10; i += 1) {
    const n = newCardNumber();
    if (!(await client.query('SELECT 1 FROM nfc_cards WHERE card_number = $1', [n])).rows.length) return n;
  }
  throw new Error('Could not issue a card number, try again');
}
/** Gives older test cards a number, expiry and CVC if they lack them. */
async function ensureCardDetails(client, row) {
  if (row.card_number) return row;
  const cvc = String(crypto.randomInt(1000)).padStart(3, '0');
  return (
    await client.query(
      `UPDATE nfc_cards SET card_number = $1, expiry = $2, cvc_enc = $3 WHERE id = $4 RETURNING *`,
      [await uniqueCardNumber(client), newExpiry(), encryptCvc(cvc), row.id],
    )
  ).rows[0];
}
const cardLast4 = (row) => (row.card_number || row.uid).slice(-4);

function publicCard(row) {
  return {
    id: row.id,
    last4: cardLast4(row),
    maskedNumber: row.card_number ? `${row.card_number.slice(0, 4)} •••• •••• ${row.card_number.slice(-4)}` : null,
    expiry: row.expiry,
    label: row.label,
    status: row.status,
    perTxLimitUsd: Number(row.per_tx_limit_usd),
    dailyLimitUsd: Number(row.daily_limit_usd),
    createdAt: row.created_at,
    lastUsedAt: row.last_used_at,
  };
}

async function merchantAccess(client, userId, merchantId) {
  const merchant = (await client.query('SELECT * FROM merchants WHERE id = $1', [merchantId])).rows[0];
  if (!merchant) return null;
  if (merchant.owner_id === userId) return merchant;
  const teller = (
    await client.query(
      `SELECT 1 FROM merchant_staff WHERE merchant_id = $1 AND user_id = $2 AND status = 'ACTIVE'`,
      [merchantId, userId],
    )
  ).rows[0];
  return teller ? merchant : null;
}

/**
 * Finds the card for a tap by its serial number (UID).
 *   - Card carries the Fareenn link: the token must match too  → verified.
 *   - Card has no link, or a link that doesn't match (serial only, e.g. a
 *     fresh MIFARE card or a mistyped record) → not verified; the charge
 *     then requires the cardholder's PIN, because a bare UID can be copied
 *     onto another card.
 * Returns null only for a serial that isn't registered.
 */
async function cardForTap(client, uid, token, lock) {
  const row = (
    await client.query(`SELECT * FROM nfc_cards WHERE uid = $1 ${lock ? 'FOR UPDATE' : ''}`, [uid])
  ).rows[0];
  if (!row) return null;
  return { card: row, verified: Boolean(token) && sameToken(row.token, token) };
}

const receiptRef = (id) => String(id).split('-')[0].toUpperCase();
const money = (amount, currency) => `${currency} ${Number(amount).toFixed(2)}`;

/**
 * E-receipt: lands in the customer's and the merchant's in-app inbox (and
 * Telegram/email if they enabled those). Best-effort, after the commit, so
 * it can never affect the payment itself.
 */
function sendReceipts(r, { customerId, merchantOwnerId, cashierId }) {
  const when = new Date(r.at).toLocaleString('en-GB', { timeZone: 'Africa/Mogadishu' });
  const data = { type: 'card_receipt', receiptId: r.id };
  notify.notifyUser(customerId, {
    kind: 'receipt',
    title: `Receipt: ${money(r.amount, r.currency)} at ${r.merchant}`,
    body: `You paid ${money(r.amount, r.currency)} to ${r.merchant} (till ${r.tillNumber}) with card •••• ${r.last4} on ${when}. Ref ${r.ref}.`,
    data: { ...data, role: 'customer' },
  });
  const merchantBody = `${r.holder} paid ${money(r.amount, r.currency)} with card •••• ${r.last4} on ${when}. Ref ${r.ref}.`;
  for (const id of new Set([merchantOwnerId, cashierId])) {
    notify.notifyUser(id, {
      kind: 'receipt', title: `Sale receipt: ${money(r.amount, r.currency)}`, body: merchantBody, data: { ...data, role: 'merchant' },
    });
  }
}

const NOT_REGISTERED = 'This card is not registered with Fareenn.';
const UNREADABLE = 'The card could not be read. Hold it still and tap again.';

/** POST /cards/nfc/prepare — a fresh token to write onto a blank card. */
router.post('/nfc/prepare', async (_req, res) => {
  const token = crypto.randomBytes(16).toString('base64url');
  res.json({ token, url: CARD_URL + token });
});

/**
 * POST /cards/nfc/link { uid, token, pin, label? } — links a card the user
 * just programmed to their own wallet. Needs their PIN and verified KYC.
 */
router.post('/nfc/link', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const uid = cleanUid(req.body?.uid);
    const token = cleanToken(req.body?.token);
    const pin = String(req.body?.pin || '');
    if (!uid || !token) return res.status(400).json({ error: 'The card could not be read. Tap it again.' });

    const user = (
      await client.query('SELECT id, pin_hash, kyc_status, role FROM users WHERE id = $1', [req.userId])
    ).rows[0];
    if (!user?.pin_hash || !(await bcrypt.compare(pin, user.pin_hash))) {
      return res.status(403).json({ error: 'Incorrect PIN' });
    }
    if (user.kyc_status !== 'APPROVED' && user.role !== 'admin') {
      return res.status(403).json({ error: 'Your identity verification must be complete before you can link a card.' });
    }

    await client.query('BEGIN');
    const taken = (await client.query('SELECT user_id FROM nfc_cards WHERE uid = $1', [uid])).rows[0];
    if (taken) {
      await client.query('ROLLBACK');
      return res.status(409).json({ error: 'This card is already linked to a Fareenn account.' });
    }
    const count = (
      await client.query(
        `SELECT COUNT(*)::int AS n FROM nfc_cards WHERE user_id = $1 AND status <> 'BLOCKED'`,
        [req.userId],
      )
    ).rows[0].n;
    if (count >= MAX_CARDS_PER_USER) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: `You can link up to ${MAX_CARDS_PER_USER} cards. Block an old card first.` });
    }
    const cvc = String(crypto.randomInt(1000)).padStart(3, '0');
    const row = (
      await client.query(
        `INSERT INTO nfc_cards (uid, token, user_id, label, issued_by, card_number, expiry, cvc_enc, chip_type)
         VALUES ($1,$2,$3,$4,$3,$5,$6,$7,$8) RETURNING *`,
        [uid, token, req.userId, String(req.body?.label || 'Fareenn card').slice(0, 40),
          await uniqueCardNumber(client), newExpiry(), encryptCvc(cvc),
          String(req.body?.chipType || (uid.length === 8 ? 'MIFARE_CLASSIC_1K' : 'NTAG')).slice(0, 30)],
      )
    ).rows[0];
    await client.query('COMMIT');
    res.status(201).json({ card: publicCard(row) });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

/** GET /cards/nfc/mine — the user's linked cards. */
router.get('/nfc/mine', async (req, res, next) => {
  try {
    const rows = (
      await pool.query('SELECT * FROM nfc_cards WHERE user_id = $1 ORDER BY created_at DESC', [req.userId])
    ).rows;
    const filled = [];
    for (const row of rows) filled.push(await ensureCardDetails(pool, row));
    res.json({ cards: filled.map(publicCard) });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /cards/nfc/:id/reveal { pin } — full card number, expiry and CVC
 * for the cardholder, after their PIN.
 */
router.post('/nfc/:id/reveal', async (req, res, next) => {
  try {
    const user = (await pool.query('SELECT pin_hash, full_name FROM users WHERE id = $1', [req.userId])).rows[0];
    if (!user?.pin_hash || !(await bcrypt.compare(String(req.body?.pin || ''), user.pin_hash))) {
      return res.status(403).json({ error: 'Incorrect PIN' });
    }
    let row = (
      await pool.query('SELECT * FROM nfc_cards WHERE id = $1 AND user_id = $2', [req.params.id, req.userId])
    ).rows[0];
    if (!row) return res.status(404).json({ error: 'Card not found' });
    row = await ensureCardDetails(pool, row);
    res.json({
      number: row.card_number.replace(/(\d{4})(?=\d)/g, '$1 '),
      expiry: row.expiry,
      cvc: decryptCvc(row.cvc_enc),
      name: String(user.full_name || '').toUpperCase(),
    });
  } catch (err) {
    next(err);
  }
});

/** POST /cards/nfc/:id/freeze { frozen } — freeze or unfreeze (also clears PIN lock). */
router.post('/nfc/:id/freeze', async (req, res, next) => {
  try {
    const frozen = req.body?.frozen !== false;
    const row = (
      await pool.query(
        `UPDATE nfc_cards SET status = $1, pin_failures = 0
          WHERE id = $2 AND user_id = $3 AND status <> 'BLOCKED' RETURNING *`,
        [frozen ? 'FROZEN' : 'ACTIVE', req.params.id, req.userId],
      )
    ).rows[0];
    if (!row) return res.status(404).json({ error: 'Card not found' });
    res.json({ card: publicCard(row) });
  } catch (err) {
    next(err);
  }
});

/** POST /cards/nfc/:id/block — permanently blocks a lost or stolen card. */
router.post('/nfc/:id/block', async (req, res, next) => {
  try {
    const row = (
      await pool.query(
        `UPDATE nfc_cards SET status = 'BLOCKED' WHERE id = $1 AND user_id = $2 RETURNING *`,
        [req.params.id, req.userId],
      )
    ).rows[0];
    if (!row) return res.status(404).json({ error: 'Card not found' });
    res.json({ card: publicCard(row) });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /cards/nfc/lookup { merchantId, uid, token } — merchant side, after a
 * tap: who is paying (first name + initial, last 4), so the cashier can
 * confirm before the customer enters their PIN. Never returns balances.
 */
router.post('/nfc/lookup', async (req, res, next) => {
  try {
    const merchant = await merchantAccess(pool, req.userId, req.body?.merchantId);
    if (!merchant || merchant.status !== 'ACTIVE') return res.status(403).json({ error: 'Merchant not active' });
    const uid = cleanUid(req.body?.uid), token = cleanToken(req.body?.token);
    if (!uid) return res.status(400).json({ error: UNREADABLE });
    const tap = await cardForTap(pool, uid, token, false);
    const card = tap?.card;
    if (!card || !card.user_id) return res.status(404).json({ error: NOT_REGISTERED, code: 'CARD_NOT_REGISTERED' });
    if (card.status !== 'ACTIVE') {
      return res.status(403).json({ error: card.status === 'FROZEN' ? 'This card is frozen.' : 'This card is blocked.' });
    }
    const holder = (
      await pool.query('SELECT first_name, last_name, full_name FROM users WHERE id = $1', [card.user_id])
    ).rows[0];
    const first = holder?.first_name || String(holder?.full_name || '').split(' ')[0] || 'Customer';
    const lastInitial = (holder?.last_name || '').slice(0, 1);
    res.json({ holder: lastInitial ? `${first} ${lastInitial}.` : first, last4: cardLast4(card), pinRequired: !tap.verified });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /cards/nfc/charge { merchantId, uid, token, amount, currency, pin? }
 * Tap and pay: charges the cardholder's wallet and credits the merchant
 * after checking the card, its per-tap and daily limits, compliance limits
 * and the balance — all in one transaction. No PIN is needed; if a PIN is
 * sent it is checked (3 wrong PINs freezes the card).
 */
router.post('/nfc/charge', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const currency = cleanCurrency(req.body?.currency);
    const amount = Math.round(Number(req.body?.amount) * 100) / 100;
    if (!Number.isFinite(amount) || amount <= 0) return res.status(400).json({ error: 'Enter an amount' });
    const uid = cleanUid(req.body?.uid), token = cleanToken(req.body?.token);
    if (!uid) return res.status(400).json({ error: UNREADABLE });
    const pin = String(req.body?.pin || '');

    await client.query('BEGIN');
    const merchant = await merchantAccess(client, req.userId, req.body?.merchantId);
    if (!merchant || merchant.status !== 'ACTIVE') {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Merchant not active' });
    }
    const tap = await cardForTap(client, uid, token, true);
    const card = tap?.card;
    if (!card || !card.user_id) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: NOT_REGISTERED, code: 'CARD_NOT_REGISTERED' });
    }
    if (card.status !== 'ACTIVE') {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: card.status === 'FROZEN' ? 'This card is frozen.' : 'This card is blocked.' });
    }
    if (card.user_id === merchant.owner_id) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'A merchant cannot charge their own card.' });
    }

    const holder = (
      await client.query('SELECT id, pin_hash, full_name, first_name, last_name FROM users WHERE id = $1', [card.user_id])
    ).rows[0];
    const holderFirst = holder?.first_name || String(holder?.full_name || '').split(' ')[0] || 'Customer';
    const holderName = holder?.last_name ? `${holderFirst} ${holder.last_name.slice(0, 1)}.` : holderFirst;
    // Serial-only tap at or above the no-PIN limit: the cardholder's PIN is
    // what proves this is really their card (a UID alone can be cloned).
    // Smaller taps go through without a PIN, capped by the card's limits.
    const noPinOk = compliance.toUsd(amount, currency) < config.cardNoPinLimitUsd;
    if (!tap.verified && !pin && !noPinOk) {
      await client.query('ROLLBACK');
      if (!holder?.pin_hash) {
        return res.status(403).json({ error: 'The cardholder has not set a Fareenn PIN yet.' });
      }
      return res.status(428).json({
        error: 'Customer: enter your Fareenn PIN',
        code: 'PIN_REQUIRED',
        holder: holderName,
        last4: cardLast4(card),
      });
    }
    if (pin && (!holder?.pin_hash || !(await bcrypt.compare(pin, holder.pin_hash)))) {
      const failures = card.pin_failures + 1;
      const freeze = failures >= MAX_PIN_FAILURES;
      await client.query(
        `UPDATE nfc_cards SET pin_failures = $1, status = CASE WHEN $2 THEN 'FROZEN' ELSE status END WHERE id = $3`,
        [failures, freeze, card.id],
      );
      await client.query(
        `INSERT INTO nfc_card_transactions (card_id, merchant_id, amount, currency, status, reason)
         VALUES ($1,$2,$3,$4,'DECLINED','Incorrect PIN')`,
        [card.id, merchant.id, amount, currency],
      );
      await client.query('COMMIT');
      return res.status(403).json({
        error: freeze
          ? 'Incorrect PIN. The card is now frozen; the customer can unfreeze it in the Fareenn app.'
          : `Incorrect PIN. ${MAX_PIN_FAILURES - failures} attempt(s) left.`,
      });
    }

    const amountUsd = compliance.toUsd(amount, currency);
    const decline = async (reason, status = 403) => {
      await client.query(
        `INSERT INTO nfc_card_transactions (card_id, merchant_id, amount, currency, amount_usd, status, reason)
         VALUES ($1,$2,$3,$4,$5,'DECLINED',$6)`,
        [card.id, merchant.id, amount, currency, amountUsd, reason],
      );
      await client.query('UPDATE nfc_cards SET pin_failures = 0 WHERE id = $1', [card.id]);
      await client.query('COMMIT');
      return res.status(status).json({ error: reason });
    };
    if (amountUsd > Number(card.per_tx_limit_usd)) {
      return decline(`Above the card limit of $${Number(card.per_tx_limit_usd).toFixed(2)} per payment.`);
    }
    const today = (
      await client.query(
        `SELECT COALESCE(SUM(amount_usd), 0) AS total FROM nfc_card_transactions
          WHERE card_id = $1 AND status = 'COMPLETED' AND created_at > now() - interval '24 hours'`,
        [card.id],
      )
    ).rows[0];
    if (Number(today.total) + amountUsd > Number(card.daily_limit_usd)) {
      return decline(`Above the card's daily limit of $${Number(card.daily_limit_usd).toFixed(2)}.`);
    }
    const limit = await compliance.checkUserLimit(client, holder.id, amountUsd, `Card payment to ${merchant.name}`);
    if (!limit.allowed) return decline('Payment requires compliance review.');

    const column = currency === 'KES' ? 'kes_balance' : 'usd_balance';
    const payer = (
      await client.query(`SELECT ${column} AS balance FROM users WHERE id = $1 FOR UPDATE`, [holder.id])
    ).rows[0];
    await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [merchant.owner_id]);
    if (Number(payer.balance) < amount) return decline(`Insufficient ${currency} balance.`, 400);

    await client.query(`UPDATE users SET ${column} = ${column} - $1 WHERE id = $2`, [amount, holder.id]);
    await client.query(`UPDATE users SET ${column} = ${column} + $1 WHERE id = $2`, [amount, merchant.owner_id]);
    const payment = (
      await client.query(
        `INSERT INTO merchant_payments (merchant_id, payer_id, currency, amount)
         VALUES ($1,$2,$3,$4) RETURNING *`,
        [merchant.id, holder.id, currency, amount],
      )
    ).rows[0];
    const tx = (
      await client.query(
        `INSERT INTO nfc_card_transactions (card_id, merchant_id, payment_id, amount, currency, amount_usd, status)
         VALUES ($1,$2,$3,$4,$5,$6,'COMPLETED') RETURNING id, created_at`,
        [card.id, merchant.id, payment.id, amount, currency, amountUsd],
      )
    ).rows[0];
    await client.query('UPDATE nfc_cards SET pin_failures = 0, last_used_at = now() WHERE id = $1', [card.id]);

    await ledger.postWithClient(
      client,
      holder.id,
      { title: `Card payment: ${merchant.name}`, rail: 'Fareenn Card' },
      [
        { accountName: `Customer ${currency} wallet`, direction: 'debit', amountUsd, memo: merchant.id },
        { accountName: 'Merchant settlement clearing', direction: 'credit', amountUsd, memo: payment.id },
      ],
    );
    await ledger.postWithClient(
      client,
      merchant.owner_id,
      { title: `Card sale: ${merchant.name}`, rail: 'Fareenn Card' },
      [
        { accountName: 'Merchant settlement clearing', direction: 'debit', amountUsd, memo: payment.id },
        { accountName: `Customer ${currency} wallet`, direction: 'credit', amountUsd, memo: merchant.id },
      ],
    );
    await client.query('COMMIT');
    const receipt = {
      id: tx.id,
      ref: receiptRef(tx.id),
      paymentId: payment.id,
      merchant: merchant.name,
      tillNumber: merchant.till_number,
      amount,
      currency,
      last4: cardLast4(card),
      holder: holderName,
      pinVerified: Boolean(pin),
      at: tx.created_at,
    };
    sendReceipts(receipt, { customerId: holder.id, merchantOwnerId: merchant.owner_id, cashierId: req.userId });
    res.status(201).json({ receipt });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    if (err.status) return res.status(err.status).json({ error: err.message });
    next(err);
  } finally {
    client.release();
  }
});

/**
 * GET /cards/nfc/receipts/:id — the full e-receipt for one card payment.
 * Visible to the cardholder and to the merchant's owner/tellers only.
 */
router.get('/nfc/receipts/:id', async (req, res, next) => {
  try {
    if (!/^[0-9a-f-]{36}$/i.test(req.params.id)) return res.status(404).json({ error: 'Receipt not found' });
    const row = (
      await pool.query(
        `SELECT t.id, t.amount, t.currency, t.amount_usd, t.status, t.reason, t.created_at, t.payment_id,
                c.user_id AS holder_id, c.card_number, c.uid,
                m.id AS merchant_id, m.name AS merchant, m.till_number, m.owner_id,
                u.first_name, u.last_name, u.full_name
           FROM nfc_card_transactions t
           JOIN nfc_cards c ON c.id = t.card_id
           JOIN merchants m ON m.id = t.merchant_id
           JOIN users u ON u.id = c.user_id
          WHERE t.id = $1`,
        [req.params.id],
      )
    ).rows[0];
    if (!row) return res.status(404).json({ error: 'Receipt not found' });
    const isHolder = row.holder_id === req.userId;
    if (!isHolder && !(await merchantAccess(pool, req.userId, row.merchant_id))) {
      return res.status(404).json({ error: 'Receipt not found' });
    }
    const first = row.first_name || String(row.full_name || '').split(' ')[0] || 'Customer';
    res.json({
      receipt: {
        id: row.id,
        ref: receiptRef(row.id),
        paymentId: row.payment_id,
        status: row.status,
        reason: row.reason,
        merchant: row.merchant,
        tillNumber: row.till_number,
        amount: Number(row.amount),
        currency: row.currency,
        amountUsd: row.amount_usd == null ? null : Number(row.amount_usd),
        last4: (row.card_number || row.uid).slice(-4),
        holder: isHolder ? row.full_name : (row.last_name ? `${first} ${row.last_name.slice(0, 1)}.` : first),
        method: 'Fareenn card (tap)',
        at: row.created_at,
        viewer: isHolder ? 'customer' : 'merchant',
      },
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
