const config = require('../config');

/**
 * Paystack Transfers (money OUT) — the counterpart to the existing Paystack
 * mobile-money *charge* flow in routes/payments.js (money IN). Two calls per
 * payout: create a transfer recipient, then initiate the transfer against
 * it. https://paystack.com/docs/transfers/single-transfers/
 *
 * Requires "Confirm transfers before sending" to be OFF in the Paystack
 * dashboard (Settings > Preferences) — otherwise Paystack holds every
 * transfer in an `otp` state pending a code sent to the account owner, and
 * there's no interactive OTP-entry step built here to clear it.
 */

async function parsePaystackResponse(response) {
  const text = await response.text();
  try {
    return text ? JSON.parse(text) : {};
  } catch (_) {
    return { raw: text };
  }
}

async function paystackFetch(path, options) {
  if (!config.paystackSecretKey) {
    throw new Error('PAYSTACK_SECRET_KEY is not configured');
  }
  let response;
  try {
    response = await fetch(`https://api.paystack.co${path}`, {
      ...options,
      headers: {
        Authorization: `Bearer ${config.paystackSecretKey}`,
        'Content-Type': 'application/json',
        ...(options?.headers || {}),
      },
    });
  } catch (err) {
    throw new Error(`Could not reach Paystack: ${err.message}`);
  }
  const data = await parsePaystackResponse(response);
  if (!response.ok || data.status === false) {
    throw new Error(data.message || `Paystack request failed with ${response.status}`);
  }
  return data;
}

/** Paystack's mobile_money recipient wants a local 07... number, not E.164
 * — different from the charge API's normalizeKenyaPhone in payments.js. */
function normalizeKenyaPhoneLocal(phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  const national = digits.startsWith('254') ? digits.slice(3) : digits.replace(/^0/, '');
  return `0${national}`;
}

/** Creates (or re-creates — Paystack doesn't dedupe) a mobile_money transfer
 * recipient for a Kenyan M-Pesa payout. Returns the recipient_code needed by
 * initiateTransfer. A fresh recipient per withdrawal keeps this in step with
 * the existing withdrawal flow, where the payout phone is per-request, not
 * fixed to the user's account phone. */
async function createMpesaRecipient({ name, phone }) {
  const data = await paystackFetch('/transferrecipient', {
    method: 'POST',
    body: JSON.stringify({
      type: 'mobile_money',
      name,
      account_number: normalizeKenyaPhoneLocal(phone),
      bank_code: 'MPESA',
      currency: 'KES',
    }),
  });
  return data.data.recipient_code;
}

/** Fires the actual payout. `amountKes` is major units (e.g. 500.00), not
 * cents. `reference` must be unique, 16-50 chars, [a-z0-9_-] only — same
 * value the /webhooks/paystack transfer.* events key off of to update the
 * movement's status asynchronously once Paystack settles it. */
async function initiateTransfer({ amountKes, recipientCode, reference, reason }) {
  const data = await paystackFetch('/transfer', {
    method: 'POST',
    body: JSON.stringify({
      source: 'balance',
      amount: Math.round(amountKes * 100),
      recipient: recipientCode,
      reference,
      reason,
    }),
  });
  return data.data;
}

/** One request per withdrawal: create the recipient, then transfer to it.
 * Throws with a Paystack-provided message on failure — callers should
 * surface that to the admin rather than silently marking the payout done. */
async function payoutToMpesa({ name, phone, amountKes, reference, reason }) {
  const recipientCode = await createMpesaRecipient({ name, phone });
  return initiateTransfer({ amountKes, recipientCode, reference, reason });
}

/** Creates a recipient for an M-Pesa Buy Goods Till number — a different
 * Paystack recipient type ('mobile_money_business', bank_code 'MPTILL')
 * from a personal phone-number payout. `account_number` here is the till
 * number itself, not a phone. Confirmed against Paystack's live
 * GET /bank?currency=KES&type=mobile_money_business — 'MPTILL' is Till,
 * 'MPPAYBILL' is Paybill (not wired up here, only Till was requested). */
async function createTillRecipient({ name, tillNumber }) {
  const data = await paystackFetch('/transferrecipient', {
    method: 'POST',
    body: JSON.stringify({
      type: 'mobile_money_business',
      name,
      account_number: String(tillNumber).trim(),
      bank_code: 'MPTILL',
      currency: 'KES',
    }),
  });
  return data.data.recipient_code;
}

/** Same one-request-per-withdrawal shape as payoutToMpesa, targeting a
 * Till number instead of a phone number. */
async function payoutToTill({ name, tillNumber, amountKes, reference, reason }) {
  const recipientCode = await createTillRecipient({ name, tillNumber });
  return initiateTransfer({ amountKes, recipientCode, reference, reason });
}

module.exports = { payoutToMpesa, payoutToTill, normalizeKenyaPhoneLocal };
