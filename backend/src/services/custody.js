/**
 * Custody engine — testnet-first HD wallet custody.
 *
 * Every customer wallet is derived from ONE master seed (BIP39/BIP44),
 * path m/44'/60'/0'/0/{wallet_index}. The seed lives in env for the
 * sandbox; in production it must move to an HSM / cloud KMS with
 * quorum-controlled access, and hot balances kept minimal.
 */
const {
  HDNodeWallet,
  Mnemonic,
  JsonRpcProvider,
  formatEther,
  parseEther,
  isAddress,
} = require('ethers');
const config = require('../config');

const provider = new JsonRpcProvider(config.ethRpcUrl);
const mnemonic = Mnemonic.fromPhrase(config.masterMnemonic);

/** Derive the signing wallet for a customer (never expose outside module). */
function deriveWallet(walletIndex) {
  return HDNodeWallet.fromMnemonic(mnemonic, `m/44'/60'/0'/0/${walletIndex}`);
}

/** Public deposit address for a customer. */
function addressFor(walletIndex) {
  return deriveWallet(walletIndex).address;
}

/** On-chain ETH balance (as decimal string, ETH units). */
async function balanceOf(address) {
  const wei = await provider.getBalance(address);
  return formatEther(wei);
}

/**
 * Sign + broadcast a withdrawal from the customer's derived wallet.
 * Returns { hash }. Throws with a friendly message on common failures.
 */
async function sendEth(walletIndex, toAddress, amountEth) {
  if (!isAddress(toAddress)) throw new Error('Invalid destination address');
  const amount = parseEther(String(amountEth));
  const signer = deriveWallet(walletIndex).connect(provider);

  const balance = await provider.getBalance(signer.address);
  if (balance <= amount) {
    throw new Error('Insufficient on-chain balance (leave room for gas)');
  }

  const tx = await signer.sendTransaction({ to: toAddress, value: amount });
  return { hash: tx.hash };
}

function networkLabel() {
  return config.network === 'mainnet' ? 'Ethereum' : 'Sepolia testnet';
}

module.exports = { addressFor, balanceOf, sendEth, networkLabel };
