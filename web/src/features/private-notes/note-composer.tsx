"use client";

import Link from "next/link";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { NOTE_LIMIT, EXPIRY_OPTIONS, validateDraft, type NoteDraft, type DraftErrors } from "./note-state";

const emptyDraft: NoteDraft = { recipientEmail: "", note: "", expiryHours: 24 };

export function NoteComposer() {
  const [draft, setDraft] = useState<NoteDraft>(emptyDraft);
  const [errors, setErrors] = useState<DraftErrors>({});
  const [reviewing, setReviewing] = useState(false);
  const reviewTitle = useRef<HTMLHeadingElement>(null);
  const emailInput = useRef<HTMLInputElement>(null);
  const noteInput = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (reviewing) reviewTitle.current?.focus();
  }, [reviewing]);

  useEffect(() => {
    if (!draft.note && !draft.recipientEmail) return;
    const warnBeforeLeaving = (event: BeforeUnloadEvent) => { event.preventDefault(); event.returnValue = ""; };
    window.addEventListener("beforeunload", warnBeforeLeaving);
    return () => window.removeEventListener("beforeunload", warnBeforeLeaving);
  }, [draft.note, draft.recipientEmail]);

  function review(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const nextErrors = validateDraft(draft);
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length) {
      if (nextErrors.recipientEmail) emailInput.current?.focus();
      else if (nextErrors.note) noteInput.current?.focus();
      return;
    }
    setDraft({ ...draft, recipientEmail: draft.recipientEmail.trim() });
    setReviewing(true);
  }

  function edit() { setReviewing(false); }

  if (reviewing) {
    return (
      <section className="note-card" aria-labelledby="review-title">
        <div className="note-card-heading"><span className="eyebrow">02 / Review</span><span className="status-chip">Draft only</span></div>
        <h2 ref={reviewTitle} tabIndex={-1} id="review-title">Ready when you are.</h2>
        <dl className="note-summary">
          <div><dt>For</dt><dd>{draft.recipientEmail}</dd></div>
          <div><dt>Available for</dt><dd>{EXPIRY_OPTIONS.find((option) => option.hours === draft.expiryHours)?.label} after sealing</dd></div>
          <div><dt>Receipt</dt><dd>Acceptance, with a timestamp</dd></div>
        </dl>
        <div className="note-message" aria-label="Your draft note">{draft.note}</div>
        <p className="note-help">The recipient must verify their email before accepting. Acceptance records a public wallet receipt; your note and their email stay off-chain.</p>
        <div className="note-notice" role="status">
          <strong>Sending isn’t available yet.</strong>
          <span>Email sign-in and secure unlocking still need to be connected and verified. This draft has not been encrypted, uploaded, or sent.</span>
        </div>
        <div className="note-actions">
          <button className="primary-button" type="button" disabled>Send private note</button>
          <button className="secondary-button" type="button" onClick={edit}>Edit note</button>
        </div>
        <button className="text-button note-reset" type="button" onClick={() => { setDraft(emptyDraft); setErrors({}); edit(); }}>Discard draft</button>
      </section>
    );
  }

  return (
    <section className="note-card" aria-labelledby="compose-title">
      <div className="note-card-heading"><span className="eyebrow">01 / Compose</span><span className="status-chip">Local draft</span></div>
      <h2 id="compose-title">A note for one person.</h2>
      <p className="note-help">Start with a harmless personal test note. Sending is currently unavailable; you can draft and review it here.</p>
      <form className="note-form" noValidate onSubmit={review}>
        <div>
          <label htmlFor="recipient-email">Recipient’s email</label>
          <input ref={emailInput} id="recipient-email" type="email" autoComplete="off" maxLength={254} value={draft.recipientEmail} placeholder="friend@example.com"
            aria-invalid={Boolean(errors.recipientEmail)} aria-describedby="recipient-help recipient-error"
            onChange={(event) => setDraft({ ...draft, recipientEmail: event.target.value })} />
          <p id="recipient-help" className="note-help">Only the intended recipient should be able to accept your note.</p>
          <p id="recipient-error" className="note-field-error" role={errors.recipientEmail ? "alert" : undefined}>{errors.recipientEmail}</p>
        </div>
        <div>
          <label htmlFor="private-note">Your note</label>
          <textarea ref={noteInput} id="private-note" rows={6} autoComplete="off" spellCheck={false} maxLength={NOTE_LIMIT} value={draft.note}
            placeholder="A few words, just for them…" aria-invalid={Boolean(errors.note)} aria-describedby="note-count note-error"
            onChange={(event) => setDraft({ ...draft, note: event.target.value })} />
          <div className="note-field-footer"><span>Stays in this tab until you leave or discard it</span><span id="note-count">{draft.note.length}/{NOTE_LIMIT}</span></div>
          <p id="note-error" className="note-field-error" role={errors.note ? "alert" : undefined}>{errors.note}</p>
        </div>
        <div>
          <label htmlFor="note-expiry">Expire after</label>
          <select id="note-expiry" value={draft.expiryHours} onChange={(event) => setDraft({ ...draft, expiryHours: Number(event.target.value) })}>
            {EXPIRY_OPTIONS.map((option) => <option key={option.hours} value={option.hours}>{option.label}</option>)}
          </select>
          <p className="note-help">The timer starts when the note is sealed, not while you’re writing.</p>
        </div>
        <button className="primary-button" type="submit">Review note <span aria-hidden="true">→</span></button>
      </form>
      <p className="note-help">Want to see the whole journey? <Link href="/preview" target="_blank" rel="noopener noreferrer">Open the sample walkthrough in a new tab</Link>.</p>
    </section>
  );
}
