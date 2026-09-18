"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { NoteShell } from "./note-shell";
import { noteStatus, STATUS_LABELS } from "./note-state";
import { newSample, restoreSample, sampleReducer, type SampleState } from "./sample-state";

const STORAGE_KEY = "nosus-monad.sample-state.v1";

export function SampleJourney() {
  const [sample, setSample] = useState<SampleState | null>(null);
  const [now, setNow] = useState(0);
  const [consent, setConsent] = useState(false);
  const [revealed, setRevealed] = useState(false);
  const [interrupted, setInterrupted] = useState(false);
  const [wrongAccount, setWrongAccount] = useState(false);
  const [storageUnavailable, setStorageUnavailable] = useState(false);
  const revealTitle = useRef<HTMLHeadingElement>(null);

  useEffect(() => {
    const time = Date.now();
    setNow(time);
    try { setSample(restoreSample(sessionStorage.getItem(STORAGE_KEY), time)); }
    catch { setSample(newSample(time)); setStorageUnavailable(true); }
    const timer = window.setInterval(() => setNow(Date.now()), 1_000);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    if (!sample) return;
    try { sessionStorage.setItem(STORAGE_KEY, JSON.stringify(sample)); }
    catch { setStorageUnavailable(true); }
  }, [sample]);

  useEffect(() => { if (revealed) revealTitle.current?.focus(); }, [revealed]);

  function reset() {
    setSample(newSample(Date.now())); setNow(Date.now()); setConsent(false);
    setRevealed(false); setInterrupted(false); setWrongAccount(false);
  }

  function advance(type: "verify" | "accept" | "expire") {
    if (!sample) return;
    setSample(sampleReducer(sample, { type, now: Date.now() }));
    setNow(Date.now());
  }

  const status = sample ? noteStatus({ recipientReady: sample.stage !== "invited", acceptedAt: sample.acceptedAt, expiresAt: sample.expiresAt }, now) : "waiting";
  const title = status === "expired" ? "This sample has expired."
    : wrongAccount ? "This note is for someone else."
    : sample?.stage === "invited" ? "A private note is waiting."
    : sample?.stage === "ready" ? "Accept your private note."
    : revealed ? "Just for you." : "Your acceptance is saved.";

  return (
    <NoteShell>
      <div className="sample-banner" role="note"><strong>Sample walkthrough</strong><span>Simulated identity, acceptance, and reveal. No email, blockchain transaction, or encryption takes place.</span></div>
      <div className="sample-heading"><div><p className="eyebrow">Try both sides of the handoff</p><h1>A note. An acceptance. A receipt.</h1></div><button className="secondary-button" onClick={reset} type="button">Restart sample</button></div>
      {!sample ? <p role="status">Preparing the sample…</p> : (
        <div className="notes-layout sample-layout">
          <section className="note-card" aria-labelledby="sample-recipient-title">
            <div className="note-card-heading"><span className="eyebrow">Recipient view · Sample</span><span className="status-chip">{STATUS_LABELS[status]}</span></div>
            <h2 id="sample-recipient-title" ref={revealTitle} tabIndex={-1}>{title}</h2>
            <p className="note-help">For friend@example.com · From Alex (sample sender, not a verified identity)</p>
            {status === "expired" ? <p>New unlock requests are no longer available. Ask the sender for a fresh note. Anything already revealed could have been retained.</p>
              : wrongAccount ? <><p>Sign in with the email this note was sent to.</p><button className="primary-button" onClick={() => setWrongAccount(false)} type="button">Return to intended sample recipient</button></>
              : sample.stage === "invited" ? <>
                <p>In the live product, you’ll verify the intended email before you can accept.</p>
                <button className="primary-button" type="button" onClick={() => advance("verify")}>Simulate email verification</button>
                <p className="note-help">No code is sent. This uses a fictional recipient.</p>
              </> : sample.stage === "ready" ? <>
                <p>Acceptance records a public wallet acknowledgement and makes the intended recipient eligible to unlock.</p>
                <label className="consent-row"><input type="checkbox" checked={consent} onChange={(event) => setConsent(event.target.checked)} /><span>I understand that acceptance is public. My email and note content stay off-chain.</span></label>
                <button className="primary-button" type="button" disabled={!consent} onClick={() => { if (consent) advance("accept"); }}>Simulate Accept & unlock</button>
              </> : revealed ? <>
                <div className="note-message"><span className="eyebrow">Sample text · Not decrypted</span><p>The surprise picnic starts by the blue bench at four. Bring your favourite board game!</p></div>
                <p className="note-help">A recipient can keep what they see. Expiry cannot erase a copy.</p>
                <button className="secondary-button" type="button" onClick={() => setRevealed(false)}>Hide sample note</button>
              </> : <>
                <div className="note-notice" role="status"><strong>{interrupted ? "The sample connection was interrupted." : "Acceptance recorded in this sample."}</strong><span>You can retry unlocking until expiry. No second acknowledgement is needed.</span></div>
                <div className="note-actions">
                  <button className="primary-button" type="button" onClick={() => { setRevealed(true); setInterrupted(false); }}>{interrupted ? "Retry sample reveal" : "Reveal sample note"}</button>
                  <button className="secondary-button" type="button" onClick={() => setInterrupted(true)}>Simulate interruption</button>
                </div>
              </>}
            <details className="notes-details">
              <summary>Explore other situations</summary>
              <div className="note-actions">
                <button className="secondary-button" type="button" disabled={status === "expired"} onClick={() => { setWrongAccount(true); setRevealed(false); }}>Try a different account</button>
                <button className="secondary-button" type="button" disabled={status === "expired"} onClick={() => { advance("expire"); setRevealed(false); }}>Expire sample</button>
              </div>
              <p>Refresh this page after acceptance to try resuming. Only sample state and timestamps are stored in this tab; your real drafts never enter this walkthrough.</p>
            </details>
          </section>
          <section className="note-card receipt-preview" aria-labelledby="sample-receipt-title">
            <div className="note-card-heading"><span className="eyebrow">Sender view · Sample</span><span className="status-chip">{STATUS_LABELS[status]}</span></div>
            <h2 id="sample-receipt-title">Your acceptance receipt.</h2>
            <dl className="note-summary">
              <div><dt>For</dt><dd>friend@example.com (fictional)</dd></div>
              <div><dt>Accepted</dt><dd>{sample.acceptedAt !== null ? new Date(sample.acceptedAt).toLocaleString() : "Not yet"}</dd></div>
              <div><dt>Expires</dt><dd>{new Date(sample.expiresAt).toLocaleString()}</dd></div>
            </dl>
            <ol className="receipt-timeline">
              <li className="complete"><strong>Sample invitation prepared</strong><p>No invitation was sent.</p></li>
              <li className={sample.stage !== "invited" ? "complete" : ""}><strong>Recipient setup</strong><p>{sample.stage === "invited" ? "Waiting for sample email verification." : "Verification simulated."}</p></li>
              <li className={sample.acceptedAt !== null ? "complete" : ""}><strong>Acceptance</strong><p>{sample.acceptedAt !== null ? "Sample acknowledgement recorded. This does not prove reading." : "Waiting for the recipient to accept."}</p></li>
            </ol>
            <details className="notes-details"><summary>Receipt details</summary><p>This is a sample receipt with no transaction hash. Real receipts will link to the confirmed transaction and encrypted-payload digest. Emails must never appear in public receipt data.</p></details>
          </section>
        </div>
      )}
      {storageUnavailable ? <p className="note-notice" role="status">Browser storage is unavailable. This sample works, but refresh will restart it.</p> : null}
      <p className="note-help sample-end">Finished exploring? <Link href="/">Write a local draft</Link>. Real sending remains unavailable while secure access and sign-in are being connected.</p>
    </NoteShell>
  );
}
