const crypto = require('crypto');
const config = require('../config');

function hashCode(code) {
  return crypto.createHash('sha256').update(String(code)).digest('hex');
}

function generateOtp() {
  return crypto.randomInt(100000, 1000000).toString();
}

async function sendEmail({ to, subject, html }) {
  if (config.emailProvider !== 'resend') {
    throw new Error(`Unsupported EMAIL_PROVIDER: ${config.emailProvider}`);
  }
  return sendWithResend({ to, subject, html });
}

async function sendWithResend({ to, subject, html }) {
  if (!config.resendApiKey) {
    throw new Error('RESEND_API_KEY not configured');
  }

  const res = await fetch(config.resendApiUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.resendApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: config.emailFrom,
      to,
      subject,
      html,
    }),
  });

  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(body?.message || body?.error || `Email send failed (${res.status})`);
  }
  return body;
}

async function sendEmailOtp({ to, code, name = 'there' }) {
  const safeName = String(name || 'there').split(' ')[0];
  return sendEmail({
    to,
    subject: 'Your RoyallPay verification code',
    html: `<div style="font-family:Arial,sans-serif;line-height:1.5;color:#111;max-width:560px">
      <h2>Hi ${safeName},</h2>
      <p>Use this code to verify your RoyallPay account:</p>
      <p style="font-size:32px;letter-spacing:6px;font-weight:700;margin:24px 0">${code}</p>
      <p style="color:#666;font-size:14px">This code expires in ${config.emailOtpTtlMinutes} minutes.</p>
      <p style="color:#888;font-size:13px">If you did not request this, you can safely ignore this email.</p>
    </div>`,
  });
}

module.exports = { generateOtp, hashCode, sendEmail, sendEmailOtp, sendWithResend };
