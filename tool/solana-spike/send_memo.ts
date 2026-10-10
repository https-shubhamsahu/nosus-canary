// NO SUS Canary: Solana devnet memo spike.
//
// Exercises the exact production code path (app/supabase/functions/canary/
// solana.ts): loads or generates a devnet relayer key, funds it by airdrop,
// sends one seal memo and one open memo, then reads one back and checks the
// text. The secret key is written to .keys/relayer.json and never printed.
//
//   npx -y deno run -A tool/solana-spike/send_memo.ts

import {
  createKeyPairSignerFromBytes,
  createKeyPairSignerFromPrivateKeyBytes,
  createSolanaRpc,
  getBase58Encoder,
  lamports,
  type Signature,
} from "npm:@solana/kit@8.4.0";
import {
  loadSolana,
  openMemo,
  sealMemo,
  sendSolanaMemo,
} from "../../app/supabase/functions/canary/solana.ts";

const KEYS_DIR = new URL(".keys/", import.meta.url);
const KEY_FILE = new URL("relayer.json", KEYS_DIR);
const MIN_BALANCE = 10_000_000n; // 0.01 SOL
const AIRDROP = lamports(1_000_000_000n); // 1 SOL

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function hex64(): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(32)), (b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function explorer(sig: string, rpcUrl: string): string {
  const cluster = rpcUrl.includes("testnet") ? "testnet" : "devnet";
  return `https://explorer.solana.com/tx/${sig}?cluster=${cluster}`;
}

// Returns the solana-keygen style JSON array (64 bytes) for the relayer,
// generating and saving a new one when the file does not exist yet.
async function loadOrCreateKeyJson(): Promise<string> {
  try {
    return (await Deno.readTextFile(KEY_FILE)).trim();
  } catch (e) {
    if (!(e instanceof Deno.errors.NotFound)) throw e;
  }
  const seed = crypto.getRandomValues(new Uint8Array(32));
  const signer = await createKeyPairSignerFromPrivateKeyBytes(seed);
  const secret = new Uint8Array(64);
  secret.set(seed, 0);
  secret.set(getBase58Encoder().encode(signer.address), 32);
  const json = JSON.stringify(Array.from(secret));
  await Deno.mkdir(KEYS_DIR, { recursive: true });
  await Deno.writeTextFile(KEY_FILE, json + "\n");
  console.log("Generated a new devnet keypair in tool/solana-spike/.keys/relayer.json");
  return json;
}

type Rpc = ReturnType<typeof createSolanaRpc>;

async function waitConfirmed(rpc: Rpc, sig: Signature, timeoutMs: number): Promise<boolean> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const { value: [status] } = await rpc.getSignatureStatuses([sig]).send();
    if (status?.err) return false;
    if (status?.confirmationStatus === "confirmed" || status?.confirmationStatus === "finalized") {
      return true;
    }
    await sleep(500);
  }
  return false;
}

async function main() {
  Deno.env.set("SOLANA_RELAYER_KEYS", await loadOrCreateKeyJson());
  const cfg = loadSolana();
  if (!cfg) throw new Error("loadSolana() returned null although SOLANA_RELAYER_KEYS is set");
  const signer = await createKeyPairSignerFromBytes(cfg.keys[0]);
  console.log(`Relayer public key: ${signer.address}`);
  console.log(`RPC: ${cfg.rpcUrl}`);
  console.log(`Memo program: ${cfg.memoProgram}`);

  const rpc = createSolanaRpc(cfg.rpcUrl);
  const balance = async () =>
    (await rpc.getBalance(signer.address, { commitment: "confirmed" }).send()).value;
  console.log(`Balance: ${Number(await balance()) / 1e9} SOL`);

  if ((await balance()) < MIN_BALANCE) {
    let funded = false;
    for (let attempt = 1; attempt <= 4 && !funded; attempt++) {
      try {
        const sig = await rpc.requestAirdrop(signer.address, AIRDROP, { commitment: "confirmed" })
          .send();
        console.log(`Airdrop requested (${attempt}/4): ${sig}`);
        funded = await waitConfirmed(rpc, sig, 30_000);
      } catch (e) {
        console.log(`Airdrop attempt ${attempt}/4 failed: ${e instanceof Error ? e.message : String(e)}`);
      }
      if (!funded && attempt < 4) await sleep(2_000 * 2 ** (attempt - 1));
    }
    if (!funded) {
      console.error(
        `Devnet airdrop is rate-limited. Fund ${signer.address} at https://faucet.solana.com and run again.`,
      );
      Deno.exit(1);
    }
    console.log(`Balance after airdrop: ${Number(await balance()) / 1e9} SOL`);
  }

  const note = `0x${hex64()}`;
  const seal = sealMemo({
    note,
    copies: 3,
    hash: `0x${hex64()}`,
    exp: Math.floor(Date.now() / 1000) + 3600,
  });
  console.log(`\nSeal memo (${new TextEncoder().encode(seal).length} bytes): ${seal}`);
  let t0 = Date.now();
  const sealSig = await sendSolanaMemo(cfg, seal);
  console.log(`  confirmed in ${Date.now() - t0} ms: ${sealSig}`);
  console.log(`  ${explorer(sealSig, cfg.rpcUrl)}`);

  const open = openMemo({ note, copy: 0, tag: `0x${hex64()}` });
  console.log(`\nOpen memo (${new TextEncoder().encode(open).length} bytes): ${open}`);
  t0 = Date.now();
  const openSig = await sendSolanaMemo(cfg, open);
  console.log(`  confirmed in ${Date.now() - t0} ms: ${openSig}`);
  console.log(`  ${explorer(openSig, cfg.rpcUrl)}`);

  // Round trip: read the seal transaction back and compare the memo text.
  const tx = await rpc
    .getTransaction(sealSig as Signature, {
      encoding: "jsonParsed",
      maxSupportedTransactionVersion: 0,
      commitment: "confirmed",
    })
    .send();
  if (!tx) throw new Error("getTransaction returned null");
  const ix = tx.transaction.message.instructions[0] as unknown as {
    program?: string;
    parsed?: unknown;
    data?: unknown;
  };
  // SPL Memo (MemoSq4…) is parsed by the RPC into a plain string; p-memo is not,
  // so fall back to decoding the raw base58 instruction data.
  const decoded = typeof ix.parsed === "string"
    ? ix.parsed
    : new TextDecoder().decode(getBase58Encoder().encode(String(ix.data ?? "")));
  console.log(`\nRead back (${ix.program ?? "raw"}): ${decoded}`);
  console.log(`Compute units: ${tx.meta?.computeUnitsConsumed ?? "?"}, fee: ${tx.meta?.fee ?? "?"} lamports`);
  if (decoded !== seal) {
    console.error("MISMATCH: decoded memo differs from the sent memo");
    Deno.exit(1);
  }
  console.log("Round trip OK: decoded memo equals the sent memo.");
  console.log(`Balance: ${Number(await balance()) / 1e9} SOL`);
}

await main();
