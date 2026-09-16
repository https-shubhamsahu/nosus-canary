# Design system

The experiment uses the visual language reviewed from the user-provided NO SUS
Burn ad kit on 2026-09-16. That kit is a visual reference only. Its product
components and deployment assumptions belong to production NO SUS and must not
be copied into this separate experiment.

## Visual rules

- Use local Geist and Geist Mono assets from `web/src/app/fonts/`.
- Keep the canvas black (`#080808`), with white type, `#888888` secondary copy,
  and thin white dividers. Use the small coral error state only for failure.
- Prefer flat rectangular surfaces, 2px corners, a white filled primary action,
  and uppercase mono labels. Do not introduce gradients, glows, neon colors,
  oversized shadows, or decorative crypto effects.
- Motion is functional and restrained: status may pulse by opacity; never use
  motion to imply that a chain or threshold action succeeded.
- The experimental/testnet and trust-limit messages are product content, not
  optional decoration. They must remain visible on every flow.

## Token layers

`web/src/app/globals.css` is the single source of truth:

1. Raw palette tokens (`--black`, `--gray-dark`, `--white`) record values.
2. Semantic tokens (`--surface`, `--text-muted`, `--line`) describe purpose.
3. Component tokens (`--button-primary-bg`) describe reusable UI roles.

Use an existing semantic token before adding a new value. Create a new raw token
only when a real, repeated need exists; then add its semantic alias.

## Component expectations

- Keep forms, receipt rows, and verifier fields as bordered information blocks.
- A status chip communicates system state; success styling is never evidence of
  a real unlock unless the verified Lit–Monad gate permits it.
- The lock is a recognisable interface mark, not a security claim. Its unlocked
  state is available only to a confirmed, unexpired recipient path.
- Preserve visible keyboard focus and `prefers-reduced-motion` support.

## Before visual changes

Read `web/README.md`, inspect only the screen you touch, and use localhost for
visual validation. Update this document if a durable visual rule changes.
