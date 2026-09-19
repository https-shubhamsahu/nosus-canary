# NO SUS — Monad Experiment

An isolated Monad-testnet experiment for one-time encrypted notes. A recipient wallet may decrypt
only after its acknowledgement is recorded on-chain and the threshold-custody gate accepts it.

This is not the production NO SUS application. It has a separate Git repository, Supabase project,
deployment, credentials, and product decision process.

## Start here

1. Read [AGENTS.md](AGENTS.md) and [docs/CURSOR_HANDOFF.md](docs/CURSOR_HANDOFF.md).
2. Complete the threshold-gate technical spike before marketing or demo claims.
3. Use only harmless, personally owned test notes on Monad testnet.

## NO SUS Canary demo

Live app: [https://shubham-sahu.me/nosus-canary/#/canary](https://shubham-sahu.me/nosus-canary/#/canary)

Until custom-domain HTTPS is enforced, the GitHub Pages origin is also HTTPS: [https://https-shubhamsahu.github.io/nosus-canary/#/canary](https://https-shubhamsahu.github.io/nosus-canary/#/canary)

## Layout

- `web/` — Next.js recipient, creator, verifier, and live-wall experience.
- `contracts/` — Solidity contract and local test suite.
- `supabase/` — isolated storage metadata schema; do not apply it to NO SUS.
- `docs/` — security model, status, setup, and Cursor continuation materials.

## Honest product statement

The on-chain receipt proves that a wallet acknowledged a committed encrypted drop. It does not prove
human comprehension, real-world identity, screenshot prevention, legal admissibility, or independently
verifiable deletion of remote storage.
