# Solana devnet memo spike

Sends one NO SUS Canary "seal" memo and one "open" memo to Solana devnet through
the production module `app/supabase/functions/canary/solana.ts` (the exact code
path the `canary` edge function uses), then reads one transaction back and
checks that the decoded memo equals what was sent. Memos carry dummy
sha256-shaped ids only; no note text, names or keys.

Deno is not installed in this repo; `npx` fetches the official npm build:

```sh
npx -y deno run -A tool/solana-spike/send_memo.ts
```

## Keys

On the first run the script generates a devnet keypair and writes it to
`tool/solana-spike/.keys/relayer.json` in `solana-keygen` format (a JSON array
of 64 bytes). The directory is git-ignored and the secret is never printed;
only the public key is. Later runs reuse the same file.

The script feeds that file to `loadSolana()` through `SOLANA_RELAYER_KEYS`, so it
also proves the JSON-array form of the secret parses. `SOLANA_RPC_URL` is
honoured if set (default `https://api.devnet.solana.com`).

## Funding

Devnet SOL is free. The script asks the RPC faucet for 1 SOL when the balance is
below 0.01 SOL and retries a few times with backoff. The public faucet is
rate-limited; if it keeps refusing, fund the printed public key by hand at
<https://faucet.solana.com> and run the script again. One memo costs 5000
lamports (0.000005 SOL), so 1 SOL covers about 200,000 memos.

## Using the key as the edge function relayer

Maintainers only, on the devnet test project only:
set `SOLANA_RELAYER_KEYS` to the contents of `relayer.json` (or to a base58
64-byte secret key; several keys may be comma-separated). Leaving it unset keeps
the Solana proof off and the function behaves exactly as before.
