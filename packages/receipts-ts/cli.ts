// Verify a NO SUS Canary receipt from the command line:
//   deno run --allow-net cli.ts <signature> [--cluster devnet|mainnet-beta] [--rpc URL] [--note <uuid>]
// Prints the decoded receipt and its Explorer link. With --note, also checks
// that the memo's note equals sha256("nosus-canary:" + uuid); exit 1 if not.
// Exit codes: 0 ok, 1 receipt error or note mismatch, 2 bad usage.

import { chainNoteId } from "./src/ids.ts";
import { type Cluster, DEFAULT_RPC_URLS, explorerTxUrl } from "./src/explorer.ts";
import { type FetchedReceipt, fetchReceipt } from "./src/fetch.ts";

const USAGE =
  "usage: cli.ts <signature> [--cluster devnet|mainnet-beta] [--rpc URL] [--note <uuid>]";
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

function time(seconds: number): string {
  return new Date(seconds * 1000).toISOString().replace(".000Z", "Z");
}

async function main(args: string[]): Promise<number> {
  const opts: Record<string, string> = {};
  const positional: string[] = [];
  for (let i = 0; i < args.length; i++) {
    const [flag, inline] = args[i].split(/=(.*)/s);
    if (flag === "-h" || flag === "--help") {
      console.log(USAGE);
      return 0;
    }
    if (!flag.startsWith("-")) {
      positional.push(args[i]);
      continue;
    }
    if (!["--cluster", "--rpc", "--note"].includes(flag)) return usage(`unknown option ${flag}`);
    const value = inline ?? args[++i];
    if (value === undefined) return usage(`${flag} needs a value`);
    opts[flag.slice(2)] = value;
  }
  if (positional.length !== 1) return usage("give exactly one transaction signature");
  const cluster = (opts.cluster ?? "devnet") as Cluster;
  if (!Object.hasOwn(DEFAULT_RPC_URLS, cluster)) {
    return usage("--cluster must be devnet or mainnet-beta");
  }
  const note = opts.note?.toLowerCase();
  if (note !== undefined && !UUID_RE.test(note)) return usage("--note must be a note UUID");

  const signature = positional[0];
  let r: FetchedReceipt;
  try {
    r = await fetchReceipt(signature, { rpcUrl: opts.rpc ?? DEFAULT_RPC_URLS[cluster] });
  } catch (e) {
    console.error(`error: ${e instanceof Error ? e.message : String(e)}`);
    return 1;
  }

  const rc = r.receipt;
  const rows: [string, string | number][] = [
    ["signature", r.signature],
    ["slot", r.slot],
    ["time", r.blockTime === null ? "unknown" : time(r.blockTime)],
    ["fee payer", r.feePayer],
    ["program", r.memoProgram],
    ["note", rc.note],
  ];
  if (rc.t === "seal") {
    rows.push(["copies", rc.copies], ["hash", rc.hash]);
    rows.push(["expires", rc.exp === 0 ? "never (0)" : `${time(rc.exp)} (${rc.exp})`]);
  } else {
    rows.push(["copy", rc.copy], ["tag", rc.tag]);
  }
  rows.push(["explorer", explorerTxUrl(r.signature, cluster)]);
  console.log(`NO SUS Canary ${rc.t} receipt (format v${rc.v})`);
  for (const [k, v] of rows) console.log(`  ${k.padEnd(10)} ${v}`);

  if (note !== undefined) {
    const expected = await chainNoteId(note);
    if (expected !== rc.note) {
      console.error(`note check: MISMATCH. chainNoteId(${note}) is ${expected}`);
      return 1;
    }
    console.log(`note check: ok, sha256("nosus-canary:${note}") matches`);
  }
  return 0;
}

function usage(problem: string): number {
  console.error(`${problem}\n${USAGE}`);
  return 2;
}

if (import.meta.main) Deno.exit(await main(Deno.args));
