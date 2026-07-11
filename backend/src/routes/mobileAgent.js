const express = require('express');
const config = require('../config');
const { planNextAction } = require('../services/mobileAgentBrain');

const router = express.Router();

/** Shared-secret gate — this endpoint isn't tied to a wallet login, it's
 * called by the one dedicated phone, so a header check is enough. */
router.use((req, res, next) => {
  if (!config.mobileAgentSharedSecret) {
    return res.status(503).json({ error: 'MOBILE_AGENT_SHARED_SECRET is not configured on the backend' });
  }
  if (req.header('X-Agent-Key') !== config.mobileAgentSharedSecret) {
    return res.status(401).json({ error: 'Missing or invalid X-Agent-Key' });
  }
  next();
});

/**
 * POST /mobile-agent/plan { history, screen, systemNote } -> one AgentAction.
 * The Android app executes the returned action, then calls this again with
 * the result folded into systemNote for the next step — see AgentBridge.kt.
 */
router.post('/plan', async (req, res, next) => {
  try {
    const history = Array.isArray(req.body?.history) ? req.body.history : [];
    const screen = req.body?.screen && typeof req.body.screen === 'object' ? req.body.screen : null;
    const systemNote = typeof req.body?.systemNote === 'string' ? req.body.systemNote : null;

    const action = await planNextAction({ history, screen, systemNote });
    res.json(action);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
