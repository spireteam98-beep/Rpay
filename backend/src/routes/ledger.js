const express = require('express');
const { requireAuth } = require('../middleware/auth');
const ledger = require('../services/ledger');

const router = express.Router();
router.use(requireAuth);

/** GET /ledger — the user's double-entry transaction history. */
router.get('/', async (req, res, next) => {
  try {
    res.json(await ledger.listForUser(req.userId));
  } catch (err) {
    next(err);
  }
});

module.exports = router;
