const config = require('../config');

const SYSTEM_PROMPT = `You are RoyallPay Mobile Agent. You control one dedicated Android phone.

The user never sends JSON. Always have a natural conversation with them — your
"message"/"question" text is the only thing they ever see, so write it like a
person, not a log line.

Capabilities: open websites, open Android apps, dial USSD codes, read the
current screen, tap buttons, scroll, enter text, select menu options, wait for
screen changes, read SMS, take screenshots, and report success or failure.

Rules:
1. Ask only for missing information.
2. Never ask the user for JSON.
3. Understand requests in plain English.
4. Before every tap, verify the expected screen against the "screen" you were
   given — if it doesn't look like what you expected, say so and ask, or
   re-read the screen, instead of tapping blind.
5. If a menu appears, read all available options off the real screen content
   (or the USSD response text) — never invent options that aren't there.
6. Tell the user the options if a choice is required (use ask_user with the
   options list).
7. Wait for the user's selection unless instructed to choose automatically.
8. Stop before any PIN, password, biometric, or authentication step — use
   stop_for_authentication and hand it back to the user. Never propose a
   tap_node or type_text against a field the screen snapshot marks as
   password/secure, or whose label mentions PIN/OTP/CVV/security code.
9. After completion, report exactly what happened (report_result), including
   any reference/confirmation code you can see on screen or in an SMS.

You will be given, each turn: the conversation so far, the current on-screen
content as a flat list of numbered elements (index, label, and whether each
is clickable/editable/password/scrollable), and sometimes a systemNote
describing what just happened after your last action (e.g. a USSD response,
a tap result, an SMS). Decide the single next action and call emit_action
with it — exactly one action per turn. Do not narrate the action you're
about to take in freeform text outside the tool call; the "message"/
"question" field inside emit_action IS what gets said to the user.`;

const EMIT_ACTION_TOOL = {
  name: 'emit_action',
  description: 'The one next action to take. Call this exactly once per turn.',
  input_schema: {
    type: 'object',
    properties: {
      type: {
        type: 'string',
        enum: [
          'say', 'ask_user', 'open_app', 'open_url', 'dial_ussd',
          'tap_node', 'type_text', 'scroll', 'wait', 'read_screen',
          'take_screenshot', 'read_recent_sms', 'stop_for_authentication',
          'report_result',
        ],
      },
      message: { type: 'string', description: 'For say / stop_for_authentication.' },
      question: { type: 'string', description: 'For ask_user — the question shown to the user.' },
      options: { type: 'array', items: { type: 'string' }, description: 'For ask_user — the real menu options.' },
      packageName: { type: 'string', description: 'For open_app, e.g. com.safaricom.mpesa.' },
      appLabel: { type: 'string', description: 'For open_app — human-readable app name.' },
      url: { type: 'string', description: 'For open_url.' },
      code: { type: 'string', description: 'For dial_ussd, e.g. *544#.' },
      nodeIndex: { type: 'integer', description: 'For tap_node / type_text — the index from the screen snapshot.' },
      text: { type: 'string', description: 'For type_text — what to type.' },
      reason: { type: 'string', description: 'For tap_node / type_text — why, for the audit trail.' },
      direction: { type: 'string', enum: ['up', 'down', 'left', 'right'] },
      timeoutMs: { type: 'integer' },
      success: { type: 'boolean', description: 'For report_result.' },
      reference: { type: 'string', description: 'For report_result — a confirmation/reference code if any.' },
    },
    required: ['type'],
  },
};

function screenToPromptText(screen) {
  if (!screen || !Array.isArray(screen.nodes) || screen.nodes.length === 0) {
    return '(nothing readable on screen)';
  }
  const lines = screen.nodes.map((node) => {
    const flags = [
      node.clickable ? 'clickable' : null,
      node.editable ? 'editable' : null,
      node.password ? 'PASSWORD' : null,
      node.scrollable ? 'scrollable' : null,
    ].filter(Boolean).join(',');
    return `[${node.index}] "${node.label}"${flags ? ` (${flags})` : ''}`;
  });
  return lines.join('\n');
}

/**
 * Asks the LLM for the single next action given the conversation, the
 * current screen, and (optionally) a note about what the previous action
 * did. Returns the raw action JSON object (shape matches AgentAction.fromJson
 * on the Android side) — the route layer is responsible for validating and
 * forwarding it as-is.
 */
async function planNextAction({ history, screen, systemNote }) {
  if (!config.anthropicApiKey) {
    throw new Error('ANTHROPIC_API_KEY is not configured on the backend');
  }

  const userTurns = (history || []).map((turn) => ({
    role: turn.role === 'assistant' ? 'assistant' : 'user',
    content: turn.content,
  }));

  const contextBlock = [
    `Current screen:\n${screenToPromptText(screen)}`,
    screen?.requiresAuthentication
      ? 'NOTE: this screen appears to require authentication (PIN/password/OTP) — do not tap or type into it.'
      : null,
    systemNote ? `What just happened: ${systemNote}` : null,
  ].filter(Boolean).join('\n\n');

  const messages = [
    ...userTurns,
    { role: 'user', content: contextBlock },
  ];

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': config.anthropicApiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: config.anthropicModel,
      max_tokens: 1024,
      system: SYSTEM_PROMPT,
      messages,
      tools: [EMIT_ACTION_TOOL],
      tool_choice: { type: 'tool', name: 'emit_action' },
    }),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`Anthropic API error (${res.status}): ${body.slice(0, 300)}`);
  }

  const data = await res.json();
  const toolUse = (data.content || []).find((block) => block.type === 'tool_use');
  if (!toolUse) {
    throw new Error('Model did not return an emit_action tool call');
  }
  return toolUse.input;
}

module.exports = { planNextAction };
