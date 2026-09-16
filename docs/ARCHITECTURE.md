# Architecture and trust model

## Flow

1. The creator encrypts a harmless personal test note in the browser with Lit threshold custody.
2. The browser stores only encrypted payload and metadata in the experiment's Supabase project.
3. The creator seals the ciphertext digest and access policy in `NoSusMonadDrops` on Monad testnet.
4. The recipient wallet calls `acknowledgeOpen`.
5. Lit allows only the acknowledged wallet to decrypt after `canDecrypt(dropId, wallet)` succeeds
   on Monad Testnet. The Lit access-control condition uses chain key `monadTestnet` and binds the
   second argument to the authenticated wallet (`:userAddress`).
6. The acknowledged wallet may retry decryption until expiry. An acknowledgement is not evidence that
   decryption succeeded, and the product does not claim to count or prevent repeated local reads.
7. The backend may remove an encrypted object after its retention window, but that deletion is
   operational—not publicly or cryptographically provable.

## What the receipt proves

It proves a wallet acknowledged a drop with a committed ciphertext digest at a chain timestamp. It does
not prove a human read it, establish real-world identity, stop screenshots, count decryptions, prove
storage deletion, or create legal evidence by itself.

## Data boundaries

| Location | May contain | Must never contain |
|---|---|---|
| Monad contract | Drop ID, encrypted-ciphertext digest, wallet addresses, expiry, timestamps | Plaintext, key, salt, filename, content |
| Browser | Plaintext while composing/decrypting, wallet session | Service-role key, deployer private key |
| Supabase | Encrypted payload, Lit metadata, public receipt metadata | Plaintext, Lit private material |
| Lit | Threshold encryption policy and encrypted material | A hidden central-release override |
