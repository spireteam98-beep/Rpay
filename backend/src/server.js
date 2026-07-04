const express = require('express');
const cors = require('cors');
const config = require('./config');
const { migrate } = require('./db');

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) =>
  res.json({ ok: true, network: config.network, service: 'royalpay-api' }),
);

app.use('/auth', require('./routes/auth'));
app.use('/wallet', require('./routes/wallet'));
app.use('/ledger', require('./routes/ledger'));

// Central error handler — no stack traces to clients.
app.use((err, _req, res, _next) => {
  console.error('[error]', err.message);
  res.status(500).json({ error: err.message || 'Internal error' });
});

migrate()
  .then(() => {
    app.listen(config.port, () => {
      console.log(`\nRoyalPay API listening on http://localhost:${config.port}`);
      console.log(`Network: ${config.network} — custody: HD wallet (BIP44)\n`);
    });
  })
  .catch((err) => {
    console.error('[db] migration failed:', err.message);
    process.exit(1);
  });
