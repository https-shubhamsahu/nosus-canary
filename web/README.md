# web

The web experience for **NO SUS — Monad Experiment**. It is a testnet-only
recipient acknowledgement and threshold-decrypt experiment.

## Entry points

- `src/app/page.tsx` — sender console and live Receipt Wall
- `src/app/d/[id]/page.tsx` — recipient acknowledgement page
- `src/app/verify/[id]/page.tsx` — public receipt verifier
- `src/lib/monad.ts` — Monad chain and contract ABI
- `src/lib/threshold.ts` — the explicit Lit–Monad technical gate
- `src/lib/lit-conditions.ts` — `canDecrypt` access-control condition; unused for encrypt/decrypt until Gate T1 is verified
- `src/app/globals.css` — local design tokens and the flat NO SUS visual system

## Public contract

No screen may claim a note can decrypt until `threshold.ts` is changed from
`spike-required` to `verified` with the two-wallet test evidence recorded in
`../docs/STATUS.md`. The UI must show the experimental/test-data label.

## Allowed dependencies

Browser components may import `@/lib/*` and other components. They may not
read server-only environment variables or use the Supabase service-role key.
Only `src/lib/server/*` and route handlers may use it.

## Visual system

Read [`../docs/DESIGN_SYSTEM.md`](../docs/DESIGN_SYSTEM.md) before visual work.
Use the local Geist assets and semantic tokens in `globals.css`; do not copy
production NO SUS Burn components or reintroduce gradient/glow styling.

## Checks

Run `npm run check` for TypeScript. Run `npm run check` in `../tool/threshold-spike` for the
condition-shape test. Use `npm run dev` for a local preview.
Run `npm run build` only through the finalization gate in the root `AGENTS.md`.
