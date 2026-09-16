"use client";

import { useState } from "react";

import { ExperimentBadge } from "@/components/experiment-badge";
import { LockOrb } from "@/components/lock-orb";
import { isDropId } from "@/lib/drop-id";
import { acknowledgeOpen } from "@/lib/drops-contract";
import { publicEnvironment } from "@/lib/env";
import { thresholdGate } from "@/lib/threshold";

type RecipientConsoleProps = { dropId: string };

export function RecipientConsole({ dropId }: RecipientConsoleProps) {
  const [message, setMessage] = useState<string>();
  const [transaction, setTransaction] = useState<string>();
  const [submitting, setSubmitting] = useState(false);

  async function acknowledge() {
    if (!isDropId(dropId)) {
      setMessage("This recipient link does not contain a valid drop identifier.");
      return;
    }
    setSubmitting(true);
    setMessage(undefined);
    try {
      const result = await acknowledgeOpen(dropId);
      setTransaction(result.hash);
      setMessage(`Acknowledgement confirmed from ${result.address}. Threshold decrypt is still gated.`);
    } catch (caught) {
      setMessage(caught instanceof Error ? caught.message : "Acknowledgement was not sent.");
    } finally {
      setSubmitting(false);
    }
  }

  const explorer = transaction
    ? `${publicEnvironment.monadExplorerUrl}/tx/${transaction}`
    : undefined;

  return (
    <main className="recipient-page">
      <ExperimentBadge />
      <div className="recipient-grid">
        <div className="recipient-copy">
          <p className="eyebrow">Recipient link</p>
          <h1>Acknowledge with your wallet.</h1>
          <p>
            This records one eligible wallet&apos;s acknowledgement on Monad Testnet. It does not prove
            you read, understood, or retained anything.
          </p>
          <dl className="receipt-facts">
            <div><dt>Drop ID</dt><dd><code>{dropId}</code></dd></div>
            <div><dt>Threshold state</dt><dd>{thresholdGate.status.replace("-", " ")}</dd></div>
          </dl>
          <button className="primary-button" onClick={acknowledge} disabled={submitting} type="button">
            {submitting ? "Submitting acknowledgement…" : "Acknowledge on Monad"}
          </button>
          {message ? <p className="inline-error" role="status">{message}</p> : null}
          {explorer ? <a className="text-button" href={explorer} target="_blank" rel="noreferrer">View transaction ↗</a> : null}
          <p className="small-note">A wallet extension on Monad Testnet is required. Use only harmless personal test data.</p>
        </div>
        <div className="recipient-orb"><LockOrb state={transaction ? "awaiting" : "sealed"} /></div>
      </div>
      <section className="glass-panel blocked-decrypt">
        <p className="eyebrow">Decrypt / guarded</p>
        <h2>Threshold decrypt is not yet enabled.</h2>
        <p>
          The app will not substitute a server-side unlock. It remains unavailable until Lit proves
          that only the acknowledged wallet can satisfy the Monad access condition.
        </p>
      </section>
    </main>
  );
}
