# Demo runbook

This is a testnet experiment. Use only harmless, personally owned test notes.
Never use credentials, third-party documents, financial records, employment
material, or sensitive personal data.

## Before the demo

1. Confirm `docs/STATUS.md` says Gate T1 is verified. If it is not, demonstrate
   the receipt interface only; do not claim a threshold unlock exists.
2. Use a fresh isolated Supabase project and testnet-only environment values.
3. Verify the current wallet, Monad network, contract address, explorer URL,
   and the explicit gas limit generated for the write.
4. Open the browser at a local preview. Have the recipient QR/link and a
   prepared test wallet ready, but do not show seed phrases or private keys.

## Live flow

1. State the promise exactly: an eligible recipient wallet can request
   decryption only after its acknowledgement is recorded on Monad Testnet.
2. Seal a harmless note. Show the digest and transaction link, never plaintext
   in a recording or logs.
3. Scan the recipient link, connect the named test wallet, and acknowledge.
4. Show the new event in the Receipt Wall and the verifier page.
5. If Gate T1 is verified, show the acknowledged wallet decrypting and the
   second wallet failing. If it is not, stop at the receipt and say so.

## What to say when challenged

- The receipt proves a wallet action against a committed encrypted drop.
- It does not prove a person read or understood content, prevent screenshots,
  identify a person, establish legal admissibility, or independently prove
  server-side deletion.
- Costs and timing are live testnet measurements, not fixed promises.
