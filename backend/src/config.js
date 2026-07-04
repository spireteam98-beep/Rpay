const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
require('dotenv').config();

const ENV_PATH = path.join(__dirname, '..', '.env');

function required(name) {
  const value = process.env[name];
  if (!value || value.trim() === '') {
    console.error(`\n[config] Missing required env var: ${name}`);
    console.error('         Copy backend/.env.example to backend/.env and fill it in.\n');
    process.exit(1);
  }
  return value.trim();
}

/** Persist a generated value into .env so it survives restarts. */
function saveToEnvFile(name, value) {
  let content = fs.existsSync(ENV_PATH) ? fs.readFileSync(ENV_PATH, 'utf8') : '';
  const line = name + '=' + value;
  const pattern = new RegExp('^' + name + '=.*$', 'm');
  content = pattern.test(content)
    ? content.replace(pattern, line)
    : content.trimEnd() + '\n' + line + '\n';
  fs.writeFileSync(ENV_PATH, content);
}

/** JWT secret: auto-generate on first boot if not provided. */
function jwtSecret() {
  const existing = (process.env.JWT_SECRET || '').trim();
  const placeholder = 'change-me-to-a-long-random-string';
  if (existing && existing !== placeholder) return existing;
  const generated = crypto.randomBytes(48).toString('hex');
  saveToEnvFile('JWT_SECRET', generated);
  console.log('[config] Generated JWT_SECRET and saved it to .env');
  return generated;
}

/**
 * Master seed: auto-generate a BIP39 mnemonic on first boot if missing.
 * TESTNET convenience only - production keys belong in an HSM/KMS.
 */
function masterMnemonic() {
  const existing = (process.env.MASTER_MNEMONIC || '').trim();
  if (existing) return existing;
  // Lazy-require so config never hard-depends on ethers being installed.
  const { Wallet } = require('ethers');
  const generated = Wallet.createRandom().mnemonic.phrase;
  saveToEnvFile('MASTER_MNEMONIC', generated);
  console.log('[config] Generated MASTER_MNEMONIC and saved it to .env');
  console.log('         Back it up - it derives every customer wallet.');
  return generated;
}

const config = {
  databaseUrl: required('DATABASE_URL'),
  jwtSecret: jwtSecret(),
  masterMnemonic: masterMnemonic(),
  ethRpcUrl: (process.env.ETH_RPC_URL || 'https://ethereum-sepolia-rpc.publicnode.com').trim(),
  network: (process.env.NETWORK || 'testnet').trim(),
  port: parseInt(process.env.PORT || '8080', 10),
};

if (config.network !== 'testnet' && config.network !== 'mainnet') {
  console.error('[config] NETWORK must be "testnet" or "mainnet".');
  process.exit(1);
}

if (config.network === 'mainnet') {
  console.warn('\n[config] MAINNET MODE - real funds. Ensure licensing, audit and');
  console.warn('         KMS/HSM key storage are in place before onboarding customers.\n');
}

module.exports = config;
