const { pool } = require('../db');
const config = require('../config');

const DAILY_LIMIT_USD = {
  1: 500,
  2: 10000,
};

async function checkUserLimit(client, userId, amountUsd, subject) {
  const user = (await client.query('SELECT kyc_tier FROM users WHERE id = $1', [userId])).rows[0];
  const limit = DAILY_LIMIT_USD[user?.kyc_tier || 1] || DAILY_LIMIT_USD[1];
  if (amountUsd <= limit) return { allowed: true, limit };

  await client.query(
    `INSERT INTO aml_cases (user_id, kind, subject, details)
     VALUES ($1, 'limitBreach', $2, $3)`,
    [userId, subject, `Attempted $${amountUsd.toFixed(2)} against daily/transaction limit $${limit}`],
  );
  return { allowed: false, limit };
}

async function screenText(client, userId, subject, text) {
  const value = String(text || '').toLowerCase();
  const risky = ['sanction', 'terror', 'weapon', 'fraud', 'scam'];
  const hit = risky.find((word) => value.includes(word));
  if (!hit) return { clear: true };

  await client.query(
    `INSERT INTO aml_cases (user_id, kind, subject, details)
     VALUES ($1, 'screeningHit', $2, $3)`,
    [userId, subject, `Keyword screening hit: ${hit}`],
  );
  return { clear: false, hit };
}

function toUsd(amount, currency) {
  return String(currency).toUpperCase() === 'KES'
    ? Number(amount) / config.kesPerUsd
    : Number(amount);
}

module.exports = { checkUserLimit, screenText, toUsd };
