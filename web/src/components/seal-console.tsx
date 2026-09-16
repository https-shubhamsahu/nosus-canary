"use client";

import { FormEvent, useState } from "react";

import { publicEnvironment, missingRuntimeConfiguration } from "@/lib/env";
import { assertThresholdGateVerified, thresholdGate } from "@/lib/threshold";

export function SealConsole() {
  const [note, setNote] = useState("");
  const [message, setMessage] = useState<string>();
  const missing = missingRuntimeConfiguration();

  function prepareDrop(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage(undefined);
    if (!note.trim()) {
      setMessage("Write a harmless personal test note first.");
      return;
    }

    try {
      assertThresholdGateVerified();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Threshold gate is not ready.");
    }
  }

  return (
    <section className="glass-panel seal-console" aria-labelledby="seal-title">
      <div className="panel-heading">
        <div>
          <p className="eyebrow">Sender console / 01</p>
          <h2 id="seal-title">Seal a one-time test note</h2>
        </div>
        <span className="status-chip blocked">Gate T1 blocked</span>
      </div>

      <p className="panel-copy">
        The note is meant to encrypt in this browser, then bind threshold decryption to an
        acknowledged Monad wallet. This interface refuses to pretend that flow is live until
        it passes the two-wallet testnet gate.
      </p>

      <form onSubmit={prepareDrop} className="seal-form">
        <label htmlFor="test-note">Harmless personal test note</label>
        <textarea
          id="test-note"
          name="test-note"
          autoComplete="off"
          maxLength={500}
          placeholder="Example: Monad demo note — nothing confidential."
          value={note}
          onChange={(event) => setNote(event.target.value)}
        />
        <div className="form-footer">
          <span>{note.length}/500</span>
          <button className="primary-button" type="submit">
            Prepare encrypted drop <span aria-hidden="true">↗</span>
          </button>
        </div>
      </form>

      <div className="gate-note">
        <strong>What is blocking the actual write?</strong>
        <span>
          Gate T1 is still {thresholdGate.status} on Lit chain {thresholdGate.accChain}.{" "}
          {thresholdGate.requiredEvidence.length} Lit–Monad test cases remain to be recorded.
          {missing.length ? ` Runtime setup also needs: ${missing.join(", ")}.` : ""}
        </span>
      </div>
      {message ? <p className="inline-error" role="alert">{message}</p> : null}
      {publicEnvironment.dropsContractAddress ? null : (
        <p className="small-note">No contract address is configured. No transaction can be sent.</p>
      )}
    </section>
  );
}
