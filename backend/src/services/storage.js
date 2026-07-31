const crypto = require('crypto');
const { Storage } = require('@google-cloud/storage');
const config = require('../config');

const storage = new Storage();
const bucket = storage.bucket(config.avatarBucket);

const ALLOWED_TYPES = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

// 4MB decoded — comfortably under the server's 6mb JSON body limit once
// base64-encoded (~1.37x), while still large enough for a real phone photo.
const MAX_BYTES = 4 * 1024 * 1024;

/** Uploads a profile photo and returns its public URL. `base64` is the raw
 * image data (no data: URI prefix — callers strip that first). */
async function uploadAvatar(userId, base64, contentType) {
  const ext = ALLOWED_TYPES[contentType];
  if (!ext) {
    throw new Error('Image must be JPEG, PNG, or WebP');
  }

  const buffer = Buffer.from(base64, 'base64');
  if (buffer.length === 0) {
    throw new Error('Empty image data');
  }
  if (buffer.length > MAX_BYTES) {
    throw new Error('Image must be under 4MB');
  }

  const filename = `avatars/${userId}-${Date.now()}-${crypto.randomBytes(4).toString('hex')}.${ext}`;
  const file = bucket.file(filename);
  await file.save(buffer, {
    contentType,
    metadata: { cacheControl: 'public, max-age=31536000' },
  });
  return `https://storage.googleapis.com/${config.avatarBucket}/${filename}`;
}

module.exports = { uploadAvatar };
