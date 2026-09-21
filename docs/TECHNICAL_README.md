# NO SUS Canary

> **Every reader gets their own copy. If it leaks, see whose copy it was.**

[![Monad Testnet](https://img.shields.io/badge/Monad-Testnet%20(Chain%2010143)-836EF9?style=flat&logo=ethereum)](https://testnet.monadscan.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](../LICENSE)
[![Flutter 3.44](https://img.shields.io/badge/Flutter-3.44.4-02569B?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Backend-Supabase%20Edge%20Functions-3ECF8E?logo=supabase)](https://supabase.com)

---

## ⚡ Quick Links (Say all 4 out loud during pitch)

| Item | Link / Value |
|---|---|
| **1. Live Public App** | **[http://shubham-sahu.me/nosus-canary/](http://shubham-sahu.me/nosus-canary/#/canary)** *(HTTPS mirror: [https://https-shubhamsahu.github.io/nosus-canary/#/canary](https://https-shubhamsahu.github.io/nosus-canary/#/canary))* |
| **2. Public GitHub Repo** | **[https://github.com/https-shubhamsahu/nosus-canary](https://github.com/https-shubhamsahu/nosus-canary)** |
| **3. Smart Contract** | [`0xb1a1858866122c84cf97861ca815fb070e010e68`](https://testnet.monadscan.com/address/0xb1a1858866122c84cf97861ca815fb070e010e68) on Monad Testnet (Chain ID `10143`) · [Verified on Sourcify](https://sourcify.dev/server/repo-ui/10143/0xb1a1858866122c84cf97861ca815fb070e010e68) |
| **4. Live Deployment** | Standalone Flutter Web + Android APK (`foo.nosus.canary`) |

---

## 🎯 What is NO SUS Canary?

When sensitive information is shared with a group—board members, investors, legal teams, journalists, or beta testers—leaks happen. Traditional watermarks are easily cropped or removed.

**NO SUS Canary** introduces invisible, cryptographic, and linguistic canary-trapping powered by **Monad**:
1. **Sender creates a note**: The sender inputs a sensitive message. NO SUS uses natural synonym/word-twin permutation (e.g. `don't`/`do not`, `organize`/`organise`, `five`/`5`) and invisible zero-width unicode steganography to generate up to 100 uniquely fingerprinted variations.
2. **Commitment on Monad**: Before distribution, the sender's client hashes all encrypted variations and permanently commits the root hash to Monad testnet via `sealNote()`. The server never receives plaintext or keys.
3. **Recipient receives a personal copy**: When reader "Priya" opens the link, the relayer records an anonymous token on Monad testnet via `openCopy()`. Priya sees her clear text with cryptographic proof.
4. **Instant Leak Detection**: If a screenshot or copied text leaks on Twitter/WhatsApp, the sender pastes the leak (or takes a photo with the Android app's OCR). The sender's device runs a local Bayesian fingerprint match against the original plan and announces:
   > **🐤 The canary sang. Copy #7 — Priya.**

---

## 🔬 Why Monad?

Canary trapping in high-stakes environments requires:
- **Parallel High Throughput**: When a company drops an all-hands memo to 1,000 employees at 9:00 AM, hundreds of concurrent claims hit the blockchain in seconds. Monad's parallel execution engine prevents nonce bottlenecks and dropped transactions.
- **Sub-Second Finality**: Readers get their verified copy instantly (< 1 second) with live explorer receipts.
- **Micro-Gas Cost**: Each copy recording costs ~0.015 MON (~78,000 gas), making enterprise-grade tamper-evident distribution economically practical.

---

## 📋 Judge & Rubrics Checklist (Monad Blitz Mumbai V4)

### Basic Points (100 / 100)
- [x] **Public GitHub repo**: [https://github.com/https-shubhamsahu/nosus-canary](https://github.com/https-shubhamsahu/nosus-canary)
- [x] **Proper README**: Complete pitch, live URL, contract address, architecture, and reproducible instructions.
- [x] **Smart contracts deployed on Monad Testnet**: [`0xb1a1858866122c84cf97861ca815fb070e010e68`](https://testnet.monadscan.com/address/0xb1a1858866122c84cf97861ca815fb070e010e68) on Chain ID `10143`.
- [x] **Project publicly hosted**: Live on custom domain `shubham-sahu.me` and GitHub Pages.

### Advance Points — Project Working (100 / 100)
- [x] **All announced functions working**: Note generation, AES encryption, unique copy distribution, Monad transaction logging, and local leak fingerprint matching.
- [x] **Live transaction on-chain during demo**: Every `sealNote` and `openCopy` records live transactions visible on [Monadscan](https://testnet.monadscan.com).
- [x] **Contract verified on explorer**: Source verified on [Sourcify / Monadscan](https://sourcify.dev/server/repo-ui/10143/0xb1a1858866122c84cf97861ca815fb070e010e68).
- [x] **Someone else can run it from README**: Zero-friction setup instructions below.

### Advance Points — Build in Public (100 / 100)
- [x] **Posted on socials**: Tagging `@monad_dev` and `@geeky_kartikey`.
- [x] **Demo video**: 30+ second running product video.
- [x] **Creative ad video**: Visual walk-through of the leak detection.

### Bonus Points
- [x] **Public page on custom domain**: `http://shubham-sahu.me/nosus-canary/` (+15 pts).
- [x] **Pre-Market Fit**: Solves real leak paranoia for crypto DAOs, legal teams, boardrooms, and venture funds.
- [x] **Revenue Model**: Freemium for individuals; tiered B2B subscriptions ($99/mo) for team audits and enterprise canary endpoints.
- [x] **Innovation & Originality**: Combines zero-width Unicode steganography, linguistic token perturbation, client-side AES-256, and Monad parallel state logs.

---

## 🚀 How to Run It Yourself (Reproduce in 3 Minutes)

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.44+
- [Node.js](https://nodejs.org/) 20+

### 1. Run the Web App
```bash
# Clone the repository
git clone https://github.com/https-shubhamsahu/nosus-canary.git
cd nosus-canary/app

# Install Flutter dependencies
flutter pub get

# Run standalone Canary web app
flutter run -d chrome --dart-define=NOSUS_CANARY_ONLY=true
```

### 2. Run Contract Tests
```bash
cd ../contracts

# Install dependencies
npm install

# Run contract tests (includes gas benchmarks)
npx hardhat test
# Output: 11 passing (sealNote gasUsed ≈ 73,833, openCopy gasUsed ≈ 78,403)
```

### 3. Build Android APK
```bash
cd ../app
flutter build apk --release --target-platform android-arm64 --dart-define=NOSUS_ALLOW_SCREEN_CAPTURE=true
```

---

## 🔒 Security & Honesty Boundaries

- **Whose copy, not who leaked it**: Canary identifies *which specific copy* was leaked. If an attacker steals Priya's unlocked phone, it reveals Priya's copy was compromised.
- **Zero Plaintext on Chain**: Monad receives only `sha256` commitment digests and salted anonymous reader tags. No plaintext, encryption keys, salts, or reader names ever touch the contract.
- **Client-Side Cryptography**: Encryption is AES-256-CBC executed in the sender's browser; the key resides solely in the `#` URL fragment and is never sent to the server.
- **No False Blame**: The matcher is strict; if a leak is too heavily mixed or partial, it names nobody rather than falsely accusing an innocent reader.

---

## 👥 Team & Acknowledgements

Built for **Monad Blitz Mumbai V4** (19 September 2026).
- **Author**: Shubham Sahu ([@shubhamsahu](https://github.com/https-shubhamsahu))
- **Live App**: [http://shubham-sahu.me/nosus-canary/](http://shubham-sahu.me/nosus-canary/)
