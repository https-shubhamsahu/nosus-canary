# NO SUS Canary: for judges and reviewers

**One line:** share a sensitive note with a group; every reader gets a secretly different copy;
every seal and every open is a Solana transaction; if a screenshot leaks, NO SUS names whose copy
it was.

| | Link |
|---|---|
| Live app (Solana devnet) | https://shubham-sahu.me/nosus-canary/ |
| Code (Apache-2.0) | https://github.com/https-shubhamsahu/nosus-canary |
| Pitch video (2:24) | [nosus-canary-pitch.mp4](https://github.com/https-shubhamsahu/nosus-canary/releases/download/v0.1.0/nosus-canary-pitch.mp4) |
| Product demo, narrated (1:18) | [nosus-canary-demo.mp4](https://github.com/https-shubhamsahu/nosus-canary/releases/download/v0.1.0/nosus-canary-demo.mp4) |
| 36-second silent demo | [GIF](docs/media/canary-demo.gif) · [MP4](docs/media/canary-demo.mp4) |
| A real open receipt | [`5TXFPfTD…oW3wAsy2` on Solana Explorer](https://explorer.solana.com/tx/5TXFPfTDFWyVe98DVPph7r55uRdJAcih6vKMBBRJKA96KtWT7Q4MUoFQG6GwH8N1FFkiMMbZzPssGtqtoW3wAsy2?cluster=devnet) |
| Every receipt so far | [Relayer account on Solana Explorer](https://explorer.solana.com/address/CCD4SUQt4No2QNidpCuNAxJZXsqY1KhxkpfkuphueQJx?cluster=devnet) |
| Receipt format | [docs/RECEIPTS_SPEC.md](docs/RECEIPTS_SPEC.md) |
| Threat model | [SECURITY.md](SECURITY.md) |
| Contact | Shubham Sahu · [shubhamsahu@nosus.foo](mailto:shubhamsahu@nosus.foo) |

## Check it yourself in 60 seconds

1. Open the [live app](https://shubham-sahu.me/nosus-canary/) → **Create a Canary link** →
   **Use the demo note** → **Create Canary link**. A "Sealed on Solana" chip appears.
2. Open the link in a private window, type any name, tap **Open my copy**. Your copy shows a
   "Recorded on Solana" chip. Click it: Solana Explorer shows one Memo instruction with hashes only.
3. Copy the reader's text. Back in the first window, open **Who opened it** and paste it into
   **Check a leak** → **Find the copy**. It names the reader.

Use harmless text only. This is devnet.

## 2-minute demo script

| Time | Do | Say |
|---|---|---|
| 0:00 | Show the landing page | "Salary sheets, offer letters and decks leak as screenshots. Today nobody can show whose copy it was." |
| 0:15 | **Create a Canary link** → **Use the demo note** | "I write the note once. Canary makes up to 100 copies that read the same, with tiny word swaps like *don't* and *do not*, and an invisible marker." |
| 0:30 | Point at the fingerprint meter, pick 10 readers, **Create Canary link** | "Every copy is encrypted in my browser. The key stays in the link. Before anyone reads, a seal goes to Solana: one hash of all ten copies." |
| 0:45 | Click **Sealed on Solana** → Explorer | "That's a real devnet transaction. One SPL Memo. No text, no names, just hashes." |
| 1:00 | Open the link in a private window, type "Priya", **Open my copy** | "Priya needs no wallet and no app. She gets her own copy, and her open is another Solana memo, paid by our relayer for about 0.000005 SOL." |
| 1:20 | Copy Priya's text. Sender window: **Who opened it**, paste into **Check a leak**, **Find the copy** | "Now imagine Priya's copy shows up in a group chat. I paste it in. Matching runs on my device." |
| 1:35 | Result card: **The canary sang · Priya · Copy 1 / 10** | "It names her copy. If too little text survived, it names nobody. It never guesses." |
| 1:45 | Click **Proof on Solana** | "And the receipt shows when her copy was opened, on a chain neither of us can edit." |
| 1:55 | Back to README roadmap | "Next: mainnet, the open receipts library, PDFs, and the Solana dApp Store." |

## FAQ

**What does a receipt prove, exactly?**
That the NO SUS relayer recorded a seal (with a commitment to every copy) or an open of copy N, at
a chain timestamp, and that the copies were committed before anyone read them. It does not prove
a person's identity, that a human read the text, or who shared a leak. Canary names *whose copy*
leaked. Phones get lost and screens get shown to friends.

**Why put this on a chain instead of in your database?**
A database row is our word, and we can edit it. A Solana memo is public, timestamped and
append-only, so the sender, the reader and a third party can all check the same record without
trusting NO SUS.

**Why Solana?**
One receipt per reader has to be cheap (each receipt pays the 5,000-lamport base fee) and fast (about a
second to confirm, so the sender sees "opened" right away). The standard SPL Memo program means
there is no custom program to audit, and Explorer shows the memo as plain text.

**Does the server see the note?**
No. Copies are encrypted on the sender's device and the AES key lives in the link's `#fragment`,
which browsers never send to a server. The server does see each reader's typed name and when they
opened, because the sender's dashboard shows it. Names never go on chain.

**Can a reader strip the marks?**
Removing the invisible marker is not enough: the word swaps still identify the copy. From the
fingerprint test harness (`app/tool/canary_fingerprint_harness.dart`, run in CI), on a note with
15 swappable words like the app's demo note:

| Leak | 20 copies | 50 copies | 100 copies |
|---|---|---|---|
| Full copy, invisible marker removed | 300 / 300 right | 300 / 300 | 300 / 300 |
| OCR-style (caps, no punctuation) | 300 / 300 right | 300 / 300 | 300 / 300 |
| 2% random typos | 300 / 300 right, 0 wrong | 300 / 300, 0 wrong | 300 / 300, 0 wrong |
| Partial excerpts (named / wrong) | 431 / 600, 0 wrong | 313 / 600, 0 wrong | 188 / 600, 0 wrong |
| Two readers blend their copies: an innocent named | 1 / 600 | 8 / 600 | 23 / 600 |

When an excerpt is too short, Canary names nobody instead of guessing. A reader who rewrites the
whole note in their own words can defeat it. Blending is the known weak spot; the app says so.

**Who pays the fees? Do readers need a wallet?**
The relayer (a Supabase Edge Function) pays and signs every memo. Readers never see a wallet.

**Are reader tags private?**
Each tag is `sha256(server salt : note id : copy number : sha256(device id))`. Without the server
salt nobody can link tags across notes or back to a device.

**Is it on mainnet?**
Not yet. Devnet only. Mainnet with priority fees and retries is the first roadmap item.

**What is open source?**
Everything in this repo, under Apache-2.0: the Flutter app, the relayer, the database schema, and
the receipts library v0.1 in TypeScript and Dart (`packages/`), which any app can use to write and
verify the same receipts.

**What is the business?**
Pre-revenue. First users we are building for: small teams, HR, founders sharing decks, and college
groups in India. Planned paid features for teams: leak alerts, a team dashboard and audit exports.
None of those are built yet.

**What traction is there?**
Canary has been live on devnet since 10 Oct 2026; its relayer has written 31 receipts (20 Oct
2026), all from our own tests and demos. The parent app, NO SUS, has been in production since July
2026 with 18 registered users and 6 active in the last 30 days (10 Oct 2026). We do not claim more
than that.

**Who is building it?**
Shubham Sahu, founder of NO SUS, B.E. Electronics & Computer Engineering at TSEC Mumbai (2028).
NO SUS has shipped 10+ releases since July 2026.
