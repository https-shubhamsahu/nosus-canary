// Sends one memo as a Solana transaction from a relayer key. A Solana
// transaction is scoped by a recent blockhash, not an account nonce, so one
// relayer key can send concurrently and no lease is needed.

import {
  address,
  appendTransactionMessageInstruction,
  createKeyPairSignerFromBytes,
  createSolanaRpc,
  createTransactionMessage,
  getBase64EncodedWireTransaction,
  getSignatureFromTransaction,
  pipe,
  setTransactionMessageFeePayerSigner,
  setTransactionMessageLifetimeUsingBlockhash,
  signTransactionMessageWithSigners,
} from "npm:@solana/kit@8.4.0";
import { Buffer } from "node:buffer";
import { getAddMemoInstruction } from "npm:@solana-program/memo@0.15.0";

// The Supabase edge runtime resolves @solana/kit's Node build, whose base64
// codec reads the global Buffer that Deno does not define.
(globalThis as { Buffer?: typeof Buffer }).Buffer ??= Buffer;

export type SendConfig = {
  rpcUrl: string;
  /** 64-byte secret keys (private key || public key); see parseRelayerKeys. */
  keys: Uint8Array[];
  /** One of MEMO_PROGRAM_IDS. */
  memoProgram: string;
};

const CONFIRM_TIMEOUT_MS = 20_000;
const CONFIRM_POLL_MS = 400;

/**
 * Sends one memo instruction from a random relayer key and waits until the
 * transaction is confirmed. Returns the base58 signature. Polls over HTTP; no
 * WebSocket subscriptions.
 */
export async function sendMemo(cfg: SendConfig, p: { memo: string }): Promise<string> {
  const rpc = createSolanaRpc(cfg.rpcUrl);
  const signer = await createKeyPairSignerFromBytes(
    cfg.keys[Math.floor(Math.random() * cfg.keys.length)],
  );
  const { value: latest } = await rpc.getLatestBlockhash({ commitment: "confirmed" }).send();

  const message = pipe(
    createTransactionMessage({ version: 0 }),
    (m) => setTransactionMessageFeePayerSigner(signer, m),
    (m) => setTransactionMessageLifetimeUsingBlockhash(latest, m),
    (m) =>
      appendTransactionMessageInstruction(
        getAddMemoInstruction(
          { memo: p.memo, signers: [signer] },
          { programAddress: address(cfg.memoProgram) },
        ),
        m,
      ),
  );
  const transaction = await signTransactionMessageWithSigners(message);
  const signature = getSignatureFromTransaction(transaction);

  await rpc
    .sendTransaction(getBase64EncodedWireTransaction(transaction), {
      encoding: "base64",
      preflightCommitment: "confirmed",
    })
    .send();

  const deadline = Date.now() + CONFIRM_TIMEOUT_MS;
  for (;;) {
    const { value: [status] } = await rpc.getSignatureStatuses([signature]).send();
    if (status?.err) {
      const err = JSON.stringify(status.err, (_, v) => (typeof v === "bigint" ? v.toString() : v));
      throw new Error(`solana memo ${signature} failed: ${err}`);
    }
    if (status?.confirmationStatus === "confirmed" || status?.confirmationStatus === "finalized") {
      return signature;
    }
    if (Date.now() >= deadline) {
      throw new Error(`solana memo ${signature} not confirmed within ${CONFIRM_TIMEOUT_MS} ms`);
    }
    await new Promise((resolve) => setTimeout(resolve, CONFIRM_POLL_MS));
  }
}
