const express = require('express');
const cors = require('cors');
const config = require('./config');
const { migrate } = require('./db');

const app = express();
app.use(cors());
// Raised from the 100kb default so a payment-proof screenshot (base64 JSON
// body, no multipart upload pipeline yet) fits in a single request.
app.use(express.json({ limit: '6mb' }));

app.get('/health', (_req, res) =>
  res.json({ ok: true, network: config.network, service: 'royallpay-api' }),
);

app.use('/auth', require('./routes/auth'));
app.use('/wallet', require('./routes/wallet'));
app.use('/ledger', require('./routes/ledger'));
app.use('/trade', require('./routes/trade'));
app.use('/mobile-money', require('./routes/mobileMoney'));
app.use('/payments', require('./routes/payments'));
app.use('/transfers', require('./routes/transfers'));
app.use('/merchants', require('./routes/merchants'));
app.use('/bills', require('./routes/bills'));
app.use('/agents', require('./routes/agents'));
app.use('/p2p', require('./routes/p2p'));
app.use('/mobile-agent', require('./routes/mobileAgent'));
app.use('/remittance', require('./routes/remittance'));
app.use('/banking', require('./routes/banking'));
app.use('/admin', require('./routes/admin'));

// Central error handler — no stack traces to clients.
app.use((err, _req, res, _next) => {
  console.error('[error]', err.message);
  res.status(500).json({ error: err.message || 'Internal error' });
});

migrate()
  .then(() => {
    app.listen(config.port, () => {
      console.log(`\nRoyallPay API listening on http://localhost:${config.port}`);
      console.log(`Network: ${config.network} — custody: HD wallet (BIP44)\n`);
    });
  })
  .catch((err) => {
    console.error('[db] migration failed:', err.message);
    process.exit(1);
  });
