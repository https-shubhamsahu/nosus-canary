# Smart contracts

`NoSusMonadDrops` is a deliberately small Monad-testnet receipt contract. It stores only encrypted
ciphertext digests, public wallet addresses, expiry, and acknowledgement state.

## Public contract

- `seal(id, ciphertextDigest, recipient, expiresAt)` creates a drop.
- `acknowledgeOpen(id)` records the one eligible opening wallet.
- `canDecrypt(id, account)` is the threshold-custody policy predicate.
- `receiptOf(id)` returns public receipt state.

The contract does not accept payments, keys, salts, plaintext, filenames, or key proofs.

## Commands

```sh
npm install
npm run test
npm run compile
```

Set `MONAD_RPC_URL` and `DEPLOYER_PRIVATE_KEY` only in a local ignored `.env`. A testnet deploy also
requires an explicit named-target approval and `CONFIRM_MONAD_DEPLOY=1`. The script refuses to
broadcast without that flag.
