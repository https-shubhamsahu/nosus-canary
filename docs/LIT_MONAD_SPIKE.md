# Gate T1 — Lit × Monad threshold-decrypt spike

This is the first technical gate. Do not enable `web/src/lib/threshold.ts`, add
a fake fallback, or describe threshold unlock as shipped until every acceptance
test below has a recorded result in `STATUS.md`.

## Preconditions

- User explicitly approves a named Monad Testnet deployment target.
- `NoSusMonadDrops` is deployed and its bytecode/constructor-free address is
  verified in the Monad explorer.
- Two controlled test wallets and only a harmless personal test note are ready.
- A current, supported Lit SDK is selected from Lit’s official documentation.
  Do not silently revive the retired V3/`@lit-protocol/lit-node-client` Datil
  packages. The selected packages for this spike are `@lit-protocol/lit-client`
  **8.3.1**, `@lit-protocol/networks` **8.4.1**, and `@lit-protocol/auth` **8.2.3**,
  targeting the Naga Dev network (`naga-dev`). Datil was sunset on 25 February 2026.

## Selected condition

The condition to send Lit is built in `web/src/lib/lit-conditions.ts` (browser)
and `tool/threshold-spike/conditions.mjs` (runner). It is an
`evmContractConditions` entry on chain key `monadTestnet` (Lit ACC schema,
chain ID 10143) that calls `canDecrypt(id, :userAddress)` and requires the
boolean result `true`.

That chain key is published by Lit. It is **not** yet recorded evidence that
Lit nodes evaluate Monad Testnet state. Run `npm run dry-run` in
`tool/threshold-spike` to print the condition. `npm run live` runs the sender,
recipient, and stranger sequence against a named testnet deployment. It needs
three controlled test-wallet keys, not a Supabase project. Set
`THRESHOLD_SPIKE_CHECK_EXPIRY=1` to include the bounded wait-and-deny expiry test.

## Condition to prove

The Lit access-control condition must evaluate the deployed contract’s
`canDecrypt(bytes32 dropId, address wallet) -> bool` against Monad Testnet.

The fixed first argument is the exact drop ID. The second argument must be the
address authenticated by the browser wallet. The condition’s result must equal
`true`. Do not use an off-chain API, a shared signed response, a server-owned
wallet, a key commitment, or a key/salt in transaction calldata.

Lit’s custom-chain name/configuration is intentionally not assumed here. Record
the supported chain identifier, SDK package version, configuration, and source
link only after the live Lit client successfully reads Monad Testnet state.

## Required evidence

For one recorded ciphertext and drop ID, capture the exact command/browser
result (redacting no plaintext is needed because use a harmless note):

1. Before `acknowledgeOpen`, recipient wallet A fails to decrypt.
2. Wallet A acknowledges and its transaction confirms. Wallet A can decrypt.
3. Wallet B attempts the same ciphertext and fails to decrypt.
4. A second `acknowledgeOpen` attempt reverts and does not change the opener.
5. A short-expiry drop lets no wallet decrypt after expiry.
6. Tampering with stored ciphertext fails integrity/decryption; no plaintext is
   logged as part of the failure.

## Implementation handoff

When all acceptance tests are clean:

1. Add the current supported Lit SDK with exact versions and a lockfile.
2. Implement browser-only encrypt/decrypt. Keep capacity credentials and any
   server credentials out of `NEXT_PUBLIC_*`; do not turn the server into a
   decryption oracle.
3. Persist only ciphertext, Lit metadata, digest, and receipt fields through a
   narrow authenticated server route after it validates the sealed transaction.
4. Replace the guarded UI state with the real flow and add focused browser
   tests for the six cases above.
5. Update `STATUS.md`, `ARCHITECTURE.md`, and `web/README.md` with the exact
   evidence and remaining limitations.

## Runner environment

The runner reads values only from the process environment. Never paste a test
wallet private key into a command history, repository file, or `NEXT_PUBLIC_*`
variable.

```text
THRESHOLD_SPIKE_RUN=1
DROPS_CONTRACT_ADDRESS=0x...
SENDER_PRIVATE_KEY=0x...
RECIPIENT_PRIVATE_KEY=0x...
STRANGER_PRIVATE_KEY=0x...
SPIKE_DROP_ID=0x... # fresh random 32-byte value
SPIKE_EXPIRY_SECONDS=300
THRESHOLD_SPIKE_CHECK_EXPIRY=1 # optional, makes the runner wait until expiry
```

The runner creates a harmless in-memory probe, prints no plaintext, and leaves
the product gate unchanged regardless of its result. Record the transaction
hashes, SDK versions, and all observed outcomes in `STATUS.md` before enabling
the browser flow.
