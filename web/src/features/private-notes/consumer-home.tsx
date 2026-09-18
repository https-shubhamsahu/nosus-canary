import Link from "next/link";
import { NoteComposer } from "./note-composer";
import { NoteShell } from "./note-shell";

export function ConsumerHome() {
  return (
    <NoteShell>
      <div className="notes-layout">
        <section className="notes-intro" aria-labelledby="notes-title">
          <p className="eyebrow">Private notes. Clear acknowledgement.</p>
          <h1 id="notes-title">A little privacy.<br /><span className="muted">A clear receipt.</span></h1>
          <p className="notes-lede">Send a private note to one person. They accept it before it unlocks, and you get an acceptance receipt.</p>
          <ol className="notes-steps">
            <li><span>01</span><div><strong>Write to someone.</strong><p>A short note, their email, and a deadline.</p></div></li>
            <li><span>02</span><div><strong>They accept & unlock.</strong><p>They confirm who they are and accept the handoff.</p></div></li>
            <li><span>03</span><div><strong>You have a receipt.</strong><p>See when they accepted. Reading isn’t tracked.</p></div></li>
          </ol>
          <Link className="secondary-button" href="/preview">Try the sample journey <span aria-hidden="true">↗</span></Link>
          <details className="notes-details">
            <summary>What does “accepted” mean?</summary>
            <p>It means the recipient’s wallet recorded an acknowledgement. It doesn’t prove that a person read or understood the note.</p>
            <p>Acceptance creates a public blockchain record. Note content and email addresses must stay off-chain. Once someone unlocks a note, they can keep a copy.</p>
            <p>This experiment is still being connected. The sample journey demonstrates the proposed experience; real sending and secure unlocking are unavailable.</p>
          </details>
        </section>
        <NoteComposer />
      </div>
    </NoteShell>
  );
}
