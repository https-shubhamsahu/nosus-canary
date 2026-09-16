# Web scope

Read the repository-root `AGENTS.md` first. This folder owns the browser
experience only.

- Keep plaintext and decryption keys out of logs, URLs, local fixtures, and
  server routes.
- Do not fake a threshold unlock. The UI must retain its blocked state until
  the Lit–Monad testnet gate in `src/lib/threshold.ts` is verified.
- Wallet writes use Monad testnet, an estimated explicit gas limit, and a
  visible transaction link. Never add a payment flow.
- Use semantic controls, keyboard focus, strong contrast, and reduced-motion
  alternatives. Every screen carries the experiment label.

Would you like to finalize today's work? If yes, say whether to verify only, build a target, or deploy a named target.

<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
