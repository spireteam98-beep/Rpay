const crypto = require('crypto');
const express = require('express');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const config = require('../config');
const ledger = require('../services/ledger');

const router = express.Router();
router.use(requireAuth);

const GATEWAY_RAIL = {
  STRIPE: 'Card',
  PAYSTACK: 'M-Pesa',
  WAAFI: 'Waafi',
};

function cleanGateway(value) {
  const gateway = String(value || '').toUpperCase();
  if (!GATEWAY_RAIL[gateway]) throw new Error('gateway must be STRIPE, PAYSTACK or WAAFI');
  return gateway;
}

function cleanCurrency(value, gateway) {
  const currency = String(value || (gateway === 'PAYSTACK' ? 'KES' : 'USD')).toUpperCase();
  if (!['KES', 'USD'].includes(currency)) throw new Error('currency must be KES or USD');
  if (gateway === 'PAYSTACK' && currency !== 'KES') {
    throw new Error('M-Pesa through Paystack must settle in KES');
  }
  return currency;
}

/** Paystack's mobile_money charge only accepts E.164 (+254...), not 07... or 254... */
function normalizeKenyaPhone(phone) {
  const digits = phone.replace(/\D/g, '');
  const national = digits.startsWith('254') ? digits.slice(3) : digits.replace(/^0/, '');
  return `+254${national}`;
}

function cleanAmount(value) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount <= 0) throw new Error('A positive amount is required');
  return Number(amount.toFixed(2));
}

function balanceColumn(currency) {
  return currency === 'KES' ? 'kes_balance' : 'usd_balance';
}

function amountUsd(amount, currency) {
  return currency === 'KES'
    ? Number((amount / config.kesPerUsd).toFixed(2))
    : Number(amount.toFixed(2));
}

async function parseGatewayResponse(response) {
  const text = await response.text();
  try {
    return text ? JSON.parse(text) : {};
  } catch (_) {
    return { raw: text };
  }
}

async function providerFetch(url, options) {
  let response;
  try {
    response = await fetch(url, options);
  } catch (err) {
    throw new Error(`Could not reach payment provider at ${url}: ${err.message}`);
  }
  const data = await parseGatewayResponse(response);
  if (!response.ok) {
    const message = data.error?.message || data.message || `Gateway request failed with ${response.status}`;
    const err = new Error(message);
    err.gatewayData = data;
    throw err;
  }
  return data;
}

async function createTopUp(client, userId, gateway, currency, amount, phone, metadata = {}) {
  const inserted = await client.query(
    `INSERT INTO payment_topups (user_id, gateway, currency, amount, phone, metadata)
     VALUES ($1,$2,$3,$4,$5,$6)
     RETURNING *`,
    [userId, gateway, currency, amount, phone || null, JSON.stringify(metadata)],
  );
  return inserted.rows[0];
}

async function markProviderRef(client, topUpId, providerRef, providerStatus, metadata = {}) {
  const updated = await client.query(
    `UPDATE payment_topups
        SET provider_ref = $1,
            provider_status = $2,
            metadata = metadata || $3::jsonb,
            updated_at = now()
      WHERE id = $4
      RETURNING *`,
    [providerRef || null, providerStatus || null, JSON.stringify(metadata), topUpId],
  );
  return updated.rows[0];
}

async function creditTopUpWithClient(client, topUpId, providerStatus, extraMetadata = {}) {
  const topUp = (
    await client.query('SELECT * FROM payment_topups WHERE id = $1 FOR UPDATE', [topUpId])
  ).rows[0];
  if (!topUp) throw new Error('Top-up not found');

  if (topUp.status === 'SUCCEEDED') {
    return { topUp, credited: false, alreadyCredited: true };
  }
  if (topUp.status !== 'PENDING') {
    throw new Error(`Top-up is ${topUp.status}`);
  }

  const column = balanceColumn(topUp.currency);
  await client.query(`UPDATE users SET ${column} = ${column} + $1 WHERE id = $2`, [
    topUp.amount,
    topUp.user_id,
  ]);
  const credited = (
    await client.query(
      `UPDATE payment_topups
          SET status = 'SUCCEEDED',
              provider_status = $1,
              metadata = metadata || $2::jsonb,
              credited_at = now(),
              updated_at = now()
        WHERE id = $3
        RETURNING *`,
      [providerStatus || 'success', JSON.stringify(extraMetadata), topUp.id],
    )
  ).rows[0];

  const usd = amountUsd(Number(topUp.amount), topUp.currency);
  await ledger.postWithClient(
    client,
    topUp.user_id,
    { title: `${GATEWAY_RAIL[topUp.gateway]} top-up`, rail: GATEWAY_RAIL[topUp.gateway] },
    [
      { accountName: `${GATEWAY_RAIL[topUp.gateway]} settlement`, direction: 'debit', amountUsd: usd, memo: topUp.provider_ref || topUp.id },
      { accountName: `Customer ${topUp.currency} wallet`, direction: 'credit', amountUsd: usd, memo: `${topUp.amount} ${topUp.currency} credited` },
    ],
  );

  return { topUp: credited, credited: true, alreadyCredited: false };
}

async function creditTopUp(topUpId, providerStatus, extraMetadata = {}) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await creditTopUpWithClient(client, topUpId, providerStatus, extraMetadata);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    throw err;
  } finally {
    client.release();
  }
}

function publicTopUp(topUp) {
  return {
    id: topUp.id,
    gateway: topUp.gateway,
    rail: GATEWAY_RAIL[topUp.gateway],
    currency: topUp.currency,
    amount: Number(topUp.amount),
    amountUsd: amountUsd(Number(topUp.amount), topUp.currency),
    providerRef: topUp.provider_ref,
    providerStatus: topUp.provider_status,
    status: topUp.status,
    creditedAt: topUp.credited_at,
    createdAt: topUp.created_at,
  };
}

router.get('/gateways', (_req, res) => {
  res.json({
    sandbox: config.paymentSandbox,
    gateways: [
      { gateway: 'STRIPE', rail: 'Card', currencies: ['USD', 'KES'] },
      { gateway: 'PAYSTACK', rail: 'M-Pesa', currencies: ['KES'] },
      { gateway: 'WAAFI', rail: 'Waafi', currencies: ['USD', 'KES'] },
    ],
  });
});

router.get('/topups', async (req, res, next) => {
  try {
    const rows = await pool.query(
      `SELECT * FROM payment_topups
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT 100`,
      [req.userId],
    );
    res.json(rows.rows.map(publicTopUp));
  } catch (err) {
    next(err);
  }
});

router.post('/topups', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const gateway = cleanGateway(req.body?.gateway);
    const currency = cleanCurrency(req.body?.currency, gateway);
    const amount = cleanAmount(req.body?.amount);
    const phone = String(req.body?.phone || '').trim();
    if (gateway === 'WAAFI' && !phone) {
      return res.status(400).json({ error: 'phone is required for Waafi top-ups' });
    }
    if (gateway === 'PAYSTACK' && !phone) {
      return res.status(400).json({ error: 'phone is required for M-Pesa top-ups' });
    }

    await client.query('BEGIN');
    let topUp = await createTopUp(client, req.userId, gateway, currency, amount, phone, {
      returnUrl: req.body?.returnUrl || config.appPaymentReturnUrl,
    });

    if (config.paymentSandbox) {
      topUp = await markProviderRef(
        client,
        topUp.id,
        `SANDBOX-${gateway}-${crypto.randomUUID()}`,
        'sandbox_success',
        { sandbox: true },
      );
      const credited = await creditTopUpWithClient(client, topUp.id, 'sandbox_success', { sandbox: true });
      await client.query('COMMIT');
      return res.status(201).json({
        topUp: publicTopUp(credited.topUp),
        amountUsd: amountUsd(amount, currency),
        credited: true,
        sandbox: true,
        message: `${amount} ${currency} credited through ${GATEWAY_RAIL[gateway]} sandbox.`,
      });
    }

    let responsePayload = {};
    if (gateway === 'STRIPE') {
      if (!config.stripeSecretKey) throw new Error('STRIPE_SECRET_KEY is not configured');
      // PaymentIntent (not Checkout Session) so the app can collect card details
      // inline with Stripe's CardField instead of redirecting to a hosted page.
      const intent = await providerFetch('https://api.stripe.com/v1/payment_intents', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${config.stripeSecretKey}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          amount: String(Math.round(amount * 100)),
          currency: currency.toLowerCase(),
          'payment_method_types[0]': 'card',
          'metadata[topUpId]': topUp.id,
          'metadata[userId]': req.userId,
        }),
      });
      topUp = await markProviderRef(client, topUp.id, intent.id, intent.status, {
        stripe: { paymentIntentId: intent.id },
      });
      responsePayload = {
        clientSecret: intent.client_secret,
        providerRef: intent.id,
      };
    }

    if (gateway === 'PAYSTACK') {
      if (!config.paystackSecretKey) throw new Error('PAYSTACK_SECRET_KEY is not configured');
      // Direct mobile money charge (STK push to the phone) instead of a hosted
      // checkout redirect, so the app never has to open a browser tab.
      const charge = await providerFetch('https://api.paystack.co/charge', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${config.paystackSecretKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          email: req.body?.email || undefined,
          amount: Math.round(amount * 100),
          currency: 'KES',
          mobile_money: {
            phone: normalizeKenyaPhone(phone),
            provider: 'mpesa',
          },
          metadata: {
            topUpId: topUp.id,
            userId: req.userId,
            currency,
            amount,
            wallet: 'KES',
          },
        }),
      });
      topUp = await markProviderRef(client, topUp.id, charge.data?.reference, charge.data?.status, {
        paystack: { chargeStatus: charge.data?.status },
      });
      responsePayload = {
        providerRef: charge.data?.reference,
        message: charge.data?.display_text || 'Check your phone to approve the M-Pesa payment.',
      };
    }

    if (gateway === 'WAAFI') {
      if (!config.waafiBackendUrl || !config.waafiMerchantUid || !config.waafiApiUserId || !config.waafiApiKey) {
        throw new Error('Waafi gateway is not configured');
      }
      const requestId = `KF-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;
      const referenceId = `KF-${topUp.id}`;
      const payload = {
        schemaVersion: '1.0',
        requestId,
        timestamp: String(Math.floor(Date.now() / 1000)),
        channelName: 'WEB',
        serviceName: 'API_PURCHASE',
        serviceParams: {
          merchantUid: config.waafiMerchantUid,
          apiUserId: config.waafiApiUserId,
          apiKey: config.waafiApiKey,
          paymentMethod: 'MWALLET_ACCOUNT',
          payerInfo: { accountNo: phone.replace(/\D/g, '') },
          transactionInfo: {
            referenceId,
            invoiceId: requestId,
            amount: String(amount),
            currency,
            description: `Kashflip ${currency} wallet top-up`,
          },
        },
        customMetadata: { topUpId: topUp.id, userId: req.userId },
      };
      // Relayed through the Render backend (same path wiilo's app uses), not called
      // directly, since Waafi is set up to accept requests from that service.
      const waafi = await providerFetch(`${config.waafiBackendUrl}/api/waafi/initiate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      if (waafi.responseCode !== '2001') {
        throw new Error(waafi.responseMsg || 'Waafi payment was declined');
      }
      topUp = await markProviderRef(client, topUp.id, referenceId, waafi.responseMsg || 'initiated', { waafi });
      responsePayload = { providerRef: referenceId, waafi };
    }

    await client.query('COMMIT');
    res.status(201).json({
      topUp: publicTopUp(topUp),
      amountUsd: amountUsd(amount, currency),
      credited: false,
      sandbox: false,
      ...responsePayload,
    });
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {/* ignore */}
    next(err);
  } finally {
    client.release();
  }
});

router.post('/topups/verify', async (req, res, next) => {
  try {
    const gateway = cleanGateway(req.body?.gateway);
    const reference = String(req.body?.reference || req.body?.paymentIntentId || '').trim();
    if (!reference) return res.status(400).json({ error: 'reference is required' });

    const topUp = (
      await pool.query(
        `SELECT * FROM payment_topups
          WHERE gateway = $1 AND provider_ref = $2 AND user_id = $3`,
        [gateway, reference, req.userId],
      )
    ).rows[0];
    if (!topUp) return res.status(404).json({ error: 'Top-up not found' });

    let verified = false;
    let providerStatus = 'verified';
    let metadata = {};

    if (gateway === 'STRIPE') {
      if (!config.stripeSecretKey) throw new Error('STRIPE_SECRET_KEY is not configured');
      if (reference.startsWith('cs_')) {
        const session = await providerFetch(`https://api.stripe.com/v1/checkout/sessions/${reference}`, {
          headers: { Authorization: `Bearer ${config.stripeSecretKey}` },
        });
        verified = session.payment_status === 'paid';
        providerStatus = session.payment_status || session.status;
        metadata = { stripeVerify: { checkoutSessionId: session.id, paymentStatus: session.payment_status } };
      } else {
        const intent = await providerFetch(`https://api.stripe.com/v1/payment_intents/${reference}`, {
          headers: { Authorization: `Bearer ${config.stripeSecretKey}` },
        });
        verified = intent.status === 'succeeded';
        providerStatus = intent.status;
        metadata = { stripeVerify: { id: intent.id, status: intent.status } };
      }
    } else if (gateway === 'PAYSTACK') {
      if (!config.paystackSecretKey) throw new Error('PAYSTACK_SECRET_KEY is not configured');
      const paystack = await providerFetch(`https://api.paystack.co/transaction/verify/${reference}`, {
        headers: { Authorization: `Bearer ${config.paystackSecretKey}` },
      });
      verified = paystack.status === true && paystack.data?.status === 'success';
      providerStatus = paystack.data?.status || paystack.message || 'unknown';
      metadata = { paystackVerify: { status: providerStatus, channel: paystack.data?.channel } };
    } else if (gateway === 'WAAFI') {
      const accepted = ['success', 'approved', 'completed', 'paid'];
      providerStatus = String(req.body?.status || '').toLowerCase();
      verified = accepted.includes(providerStatus);
      metadata = { waafiVerify: { status: providerStatus, source: 'manual_or_callback' } };
    }

    if (!verified) {
      return res.status(400).json({ verified: false, providerStatus, topUp: publicTopUp(topUp) });
    }

    const credited = await creditTopUp(topUp.id, providerStatus, metadata);
    res.json({
      verified: true,
      credited: credited.credited,
      alreadyCredited: credited.alreadyCredited,
      amountUsd: amountUsd(Number(credited.topUp.amount), credited.topUp.currency),
      topUp: publicTopUp(credited.topUp),
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
