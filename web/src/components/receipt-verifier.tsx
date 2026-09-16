"use client";

import { useEffect, useState } from "react";
import type { Address } from "viem";

import { ExperimentBadge } from "@/components/experiment-badge";
import { isDropId } from "@/lib/drop-id";
import { canDecrypt, receiptOf } from "@/lib/drops-contract";
import { publicEnvironment } from "@/lib/env";
import { ZERO_ADDRESS } from "@/lib/monad";

type Receipt = {
  id: string;
  source: "chain" | "backend";
  senderWallet: string;
  recipientWallet: string | null;
  openerWallet: string | null;
  ciphertextDigest: string;
  expiresAt: string | null;
  sealedTxHash: string | null;
  openedTxHash: string | null;
  createdAt: string;
  openedAt: string | null;
  openerCanDecrypt: boolean | null;
};

function chainLink(hash: string | null) {
  return hash ? `${publicEnvironment.monadExplorerUrl}/tx/${hash}` : undefined;
}

function formatUnix(seconds: bigint): string | null {
  if (seconds === 0n) return null;
  return new Date(Number(seconds) * 1000).toISOString();
}

function emptyAddress(value: Address): string | null {
  return value.toLowerCase() === ZERO_ADDRESS ? null : value;
}

export function ReceiptVerifier({ dropId }: { dropId: string }) {
  const invalidId = !isDropId(dropId);
  const [receipt, setReceipt] = useState<Receipt>();
  const [error, setError] = useState<string | undefined>(
    invalidId ? "This verifier link does not contain a valid drop identifier." : undefined,
  );

  useEffect(() => {
    if (!isDropId(dropId)) return;
    const id = dropId;
    let active = true;
    async function load() {
      try {
        if (publicEnvironment.dropsContractAddress) {
          const onChain = await receiptOf(id);
          const openerWallet = emptyAddress(onChain.opener);
          const openerCanDecrypt = openerWallet
            ? await canDecrypt(id, onChain.opener)
            : false;
          if (!active) return;
          setReceipt({
            id,
            source: "chain",
            senderWallet: onChain.sender,
            recipientWallet: emptyAddress(onChain.recipient),
            openerWallet,
            ciphertextDigest: onChain.ciphertextDigest,
            expiresAt: formatUnix(onChain.expiresAt),
            sealedTxHash: null,
            openedTxHash: null,
            createdAt: formatUnix(onChain.sealedAt) ?? "",
            openedAt: formatUnix(onChain.openedAt),
            openerCanDecrypt,
          });
          return;
        }

        const response = await fetch(`/api/drops/${encodeURIComponent(id)}`, { cache: "no-store" });
        const body = (await response.json()) as Omit<Receipt, "source" | "openerCanDecrypt"> & { error?: string };
        if (!response.ok) throw new Error(body.error ?? "Receipt was not found.");
        if (active) {
          setReceipt({
            ...body,
            source: "backend",
            openerCanDecrypt: null,
          });
        }
      } catch (caught) {
        if (active) setError(caught instanceof Error ? caught.message : "Receipt unavailable.");
      }
    }
    void load();
    return () => { active = false; };
  }, [dropId]);

  return (
    <main className="verifier-page">
      <ExperimentBadge />
      <p className="eyebrow">Public verifier</p>
      <h1>Inspect the receipt. Don&apos;t overread it.</h1>
      <p className="verifier-lede">The record commits to encrypted data and wallet actions. It cannot attest to human understanding or real-world identity.</p>
      {error ? <p className="inline-error" role="alert">{error}</p> : null}
      {!error && !receipt ? <p className="loading-line" aria-live="polite">Looking up the isolated receipt…</p> : null}
      {receipt ? (
        <section className="receipt-card" aria-label="Drop receipt">
          <div className="receipt-card-header">
            <span className={receipt.openedAt ? "status-chip opened" : "status-chip sealed"}>
              {receipt.openedAt ? "Acknowledged" : "Sealed"}
            </span>
            <code>{receipt.id}</code>
          </div>
          <dl className="verifier-grid">
            <div><dt>Source</dt><dd>{receipt.source === "chain" ? "Monad Testnet contract" : "Isolated backend"}</dd></div>
            <div><dt>Ciphertext digest</dt><dd><code>{receipt.ciphertextDigest}</code></dd></div>
            <div><dt>Sender wallet</dt><dd><code>{receipt.senderWallet}</code></dd></div>
            <div><dt>Recipient wallet</dt><dd><code>{receipt.recipientWallet ?? "Open recipient"}</code></dd></div>
            <div><dt>Acknowledging wallet</dt><dd><code>{receipt.openerWallet ?? "Not yet acknowledged"}</code></dd></div>
            <div>
              <dt>On-chain canDecrypt(opener)</dt>
              <dd>
                {receipt.openerCanDecrypt === null
                  ? "Unavailable until the contract address is configured."
                  : receipt.openerCanDecrypt
                    ? "true"
                    : "false"}
              </dd>
            </div>
            <div><dt>Expiry</dt><dd>{receipt.expiresAt ?? "No expiry recorded"}</dd></div>
            <div><dt>Recorded</dt><dd>{receipt.createdAt}</dd></div>
          </dl>
          <div className="receipt-links">
            {chainLink(receipt.sealedTxHash) ? <a className="text-button" href={chainLink(receipt.sealedTxHash)} target="_blank" rel="noreferrer">Seal transaction ↗</a> : null}
            {chainLink(receipt.openedTxHash) ? <a className="text-button" href={chainLink(receipt.openedTxHash)} target="_blank" rel="noreferrer">Acknowledgement transaction ↗</a> : null}
          </div>
        </section>
      ) : null}
    </main>
  );
}
