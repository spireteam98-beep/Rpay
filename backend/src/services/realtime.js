const { EventEmitter } = require('events');

/**
 * In-process real-time bus. notifyUser() and direct messages publish here;
 * GET /social/stream (Server-Sent Events) relays a user's events to every
 * app they have open. Single-instance only: with several API replicas, swap
 * this for Postgres LISTEN/NOTIFY or Redis pub/sub.
 */
const bus = new EventEmitter();
bus.setMaxListeners(0); // one listener per open app connection

function publish(userId, event, payload) {
  if (!userId) return;
  bus.emit(`user:${userId}`, { event, payload });
}

function subscribe(userId, handler) {
  const key = `user:${userId}`;
  bus.on(key, handler);
  return () => bus.off(key, handler);
}

module.exports = { publish, subscribe };
