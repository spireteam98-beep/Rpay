const jwt = require('jsonwebtoken');
const config = require('../config');

/**
 * Verifies a Firebase Authentication ID token (the token the Flutter app
 * gets from `FirebaseAuth.instance.currentUser.getIdToken()` after Google
 * sign-in) without needing firebase-admin or a service-account key.
 *
 * Follows Firebase's documented manual-verification rules
 * (https://firebase.google.com/docs/auth/admin/verify-id-tokens#verify_id_tokens_using_a_third-party_jwt_library):
 *   - RS256, signed by one of Google's `securetoken` public certs (by `kid`)
 *   - aud === project ID, iss === https://securetoken.google.com/<project ID>
 *   - non-empty sub, not expired, auth_time in the past
 */

const CERTS_URL =
  'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

let cachedCerts = null;
let cachedUntil = 0;

async function getCerts() {
  if (cachedCerts && Date.now() < cachedUntil) return cachedCerts;
  const res = await fetch(CERTS_URL);
  if (!res.ok) throw new Error(`Could not fetch Firebase signing certs (${res.status})`);
  const certs = await res.json();
  const cacheControl = res.headers.get('cache-control') || '';
  const maxAge = Number((cacheControl.match(/max-age=(\d+)/) || [])[1] || 3600);
  cachedCerts = certs;
  cachedUntil = Date.now() + maxAge * 1000;
  return certs;
}

class FirebaseAuthError extends Error {}

function isConfigured() {
  return Boolean(config.firebaseProjectId);
}

/** Returns the decoded token claims, or throws FirebaseAuthError. */
async function verifyIdToken(idToken) {
  const projectId = config.firebaseProjectId;
  if (!projectId) throw new FirebaseAuthError('Google sign-in is not configured');
  if (!idToken || typeof idToken !== 'string') {
    throw new FirebaseAuthError('Missing Google sign-in token');
  }

  const decoded = jwt.decode(idToken, { complete: true });
  if (!decoded || decoded.header?.alg !== 'RS256' || !decoded.header?.kid) {
    throw new FirebaseAuthError('Invalid Google sign-in token');
  }

  let certs = await getCerts();
  let cert = certs[decoded.header.kid];
  if (!cert) {
    // Google rotates keys; refetch once in case our cache is stale.
    cachedUntil = 0;
    certs = await getCerts();
    cert = certs[decoded.header.kid];
  }
  if (!cert) throw new FirebaseAuthError('Invalid Google sign-in token');

  let claims;
  try {
    claims = jwt.verify(idToken, cert, {
      algorithms: ['RS256'],
      audience: projectId,
      issuer: `https://securetoken.google.com/${projectId}`,
    });
  } catch (_) {
    throw new FirebaseAuthError('Google sign-in expired — please try again');
  }

  if (!claims.sub || typeof claims.sub !== 'string') {
    throw new FirebaseAuthError('Invalid Google sign-in token');
  }
  if (claims.auth_time && claims.auth_time * 1000 > Date.now() + 60 * 1000) {
    throw new FirebaseAuthError('Invalid Google sign-in token');
  }
  return claims;
}

module.exports = { verifyIdToken, isConfigured, FirebaseAuthError };
