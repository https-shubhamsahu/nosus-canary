# Gate T1 runner

Dry-run the Lit `canDecrypt` condition without enabling the product.

```sh
npm install
npm run check
npm run dry-run
```

`npm run connect` handshakes Lit naga-dev and attempts a client-side encrypt. That still
does not prove decryption, does not deploy the contract, and does not flip the product
gate. `npm run live` additionally requires `THRESHOLD_SPIKE_RUN=1`, a deployed
`NoSusMonadDrops` address, and two controlled test wallets.

A successful live run still does not flip `web/src/lib/threshold.ts` until every case in
`docs/LIT_MONAD_SPIKE.md` is recorded in `docs/STATUS.md`.
