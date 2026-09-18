# NO SUS — PROJECT CONSTITUTION
> Authoritative, permanent guide on product vision, standards, and rules. This document does NOT track active developments or session logs.

---

## 1. Product Vision
**One-Sentence Vision:**
NO SUS lets people share a sensitive document, know when it was opened, and retain simple control over the link without forcing recipients to register or install anything.

**Target Users:**
1. **Students, professionals, and small teams**: Sharing documents that need context, visibility, or a revocable link.
2. **Privacy-conscious communicators**: Exchanging one-time secrets (credentials, private messages) over a client-encrypted, self-destructing channel.

---

## 2. Founder Philosophy
1. **Zero-Budget, Solo Leverage**: Optimize all architecture for a single developer. Maximize generous free tiers (Supabase, Deno, Cloudflare) and avoid operational overhead.
2. **Viral-Growth Distribution**: To access a SecureSend document or open a Burn Note, the recipient must interact with the platform. The product drives its own distribution.
3. **Cryptographic & Technical Honesty**: Copy and brand claims must never outrun the actual cryptography. Do not claim screenshot-proofing on browsers or total server blindness until client-side key generation (M10) is built.

---

## 3. Version 1 Scope
V1 focuses on shipping a highly stable, low-maintenance, polished web-first document link security tool:
* **SecureSend**: Share links with expiration dates, maximum view counts, touch-to-reveal blur, dynamic recipient-email watermarks, and real-time view logs.
* **Burn Notes**: Client-side AES-256 encrypted short text notes with keys kept in the URL hash fragment (zero-knowledge) and destroyed atomically on read.

---

## 4. Long-Term Vision
* **Optional document assistance**: A future Gemini or on-device adapter may help an authorized user summarize or understand a document. It is always optional, feature-flagged, and cannot block core sharing.

---

## 5. Engineering & Security Philosophy
* **RLS-First Security**: Every table must have Row-Level Security enabled. RLS policies must prevent data leaks even if client applications are fully compromised.
* **Server Boundary**: The mobile/web client must never receive server-side credentials or communicate directly with external cloud storage. Sensitive server operations go through Supabase Edge Functions.
* **Client-Side Secret Ownership**: For zero-knowledge features, the keys must be generated, stored, and used entirely in the client browser. No key material may ever touch the server database or logs.
* **Shipping Over Perfection**: Focus on production readiness, simplicity, and maintainability over unnecessary optimizations or architectural complexity.

---

## 6. UI Philosophy
* **Monochrome Paper-Ink Identity**: Clean, distraction-free near-black/near-white visuals. Use `NoSusTheme` spacing, radii, and color tokens.
* **Typography**: Outfit for display/headings (bold, large letter-spacing), Inter for body/labels (high readability).
* **Frictionless Onboarding**: Skip gates, magic links, or OTP recovery should guide users into utility as fast as possible.

---

## 7. Coding Standards & Conventions
* **Clean Architecture**: Core and new features must follow strict separation of layers:
  * `Domain`: Pure Dart interfaces, entities, and business logic.
  * `Data`: Supabase implementations, local/network data sources, and models.
  * `Presentation`: Riverpod state providers, controllers, and UI widgets.
* **Service Singletons**: Legacy or auxiliary features may use simple singleton helper services (`SupabaseService`, `AuditService`, `ScreenshotGuard`) injected via Riverpod providers.
* **No Duplicate Migrations**: SQL migrations must be incremental, idempotent, and fully reversible.
* **Remove Dead Code**: Clean up unused imports, deprecated assets, and unreferenced functions after edits.

---

## 8. Non-Negotiable Rules
1. **Never hardcode secrets** (must use `.env` / `--dart-define-from-file`).
2. **Never bypass repositories** in presentation code.
3. **Never allow unauthenticated INSERTs** into system logs or tables except where explicitly designed (e.g. Burn Notes insert, which is encrypted client-side).
4. **No v2/v3 duplicate files** or split branch iterations.
