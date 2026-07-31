const config = require('../config');
const { pool } = require('../db');
const email = require('./email');

/** Best-effort Telegram push via the bot API — never throws. Requires the
 * user to have opened the bot/Mini App at least once (their telegram_id
 * only becomes a valid chat_id once they have). */
async function sendTelegramMessage(telegramId, text) {
  if (!config.telegramBotToken || !telegramId) return;
  try {
    await fetch(`https://api.telegram.org/bot${config.telegramBotToken}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: telegramId, text }),
    });
  } catch (_) {
    // ignore — notifications are best-effort
  }
}

/**
 * Sends a real notification over whichever channel(s) the user has enabled
 * and available: Telegram (if they signed in via Telegram — telegram_id
 * set — and push notifications are on) and/or email (if verified and email
 * notifications are on). No SMS channel yet — no SMS provider is
 * configured, so the "SMS notifications" toggle stays a local-only
 * preference for now rather than pretending to send something it can't.
 *
 * Never throws — a notification failure must never affect the transaction
 * or webhook that triggered it.
 */
async function notifyUser(userId, { title, body }) {
  try {
    const user = (
      await pool.query(
        `SELECT telegram_id, email, email_verified, notify_push, notify_email
           FROM users WHERE id = $1`,
        [userId],
      )
    ).rows[0];
    if (!user) return;

    const tasks = [];
    if (user.notify_push && user.telegram_id) {
      tasks.push(sendTelegramMessage(user.telegram_id, `${title}\n${body}`));
    }
    if (user.notify_email && user.email && user.email_verified) {
      tasks.push(
        email.sendEmail({
          to: user.email,
          subject: title,
          html: `<div style="font-family:Arial,sans-serif;line-height:1.5;color:#111;max-width:560px">
            <p style="font-size:16px">${body}</p>
          </div>`,
        }),
      );
    }
    await Promise.allSettled(tasks);
  } catch (_) {
    // ignore — see docstring
  }
}

module.exports = { notifyUser };
