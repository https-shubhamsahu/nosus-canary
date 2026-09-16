# Gate T1 runner

This runner is the first proof for the product promise. It uses three controlled
test wallets: a sender seals a harmless probe for the recipient, the recipient
is denied before acknowledgement, decrypts after acknowledgement, and a stranger
is denied. It never prints the plaintext probe.

Dry-run the Lit `canDecrypt` condition without enabling the product.

```sh
npm install
npm run check
npm run dry-run
```

`npm run connect` handshakes Lit naga-dev and attempts a client-side encrypt. That still
does not prove decryption, does not deploy the contract, and does not flip the product
gate. `npm run live` additionally requires `THRESHOLD_SPIKE_RUN=1`, a deployed
`NoSusMonadDrops` address, and three controlled test wallets. Set
`THRESHOLD_SPIKE_CHECK_EXPIRY=1` to wait for and verify expiry in the same run.

A successful live run still does not flip `web/src/lib/threshold.ts` until every case in
`docs/LIT_MONAD_SPIKE.md` is recorded in `docs/STATUS.md`.
