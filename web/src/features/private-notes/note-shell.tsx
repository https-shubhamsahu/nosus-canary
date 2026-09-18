import Link from "next/link";
import { ExperimentBadge } from "@/components/experiment-badge";

export function NoteShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="notes-app">
      <a className="skip-link" href="#main-content">Skip to content</a>
      <header className="topbar">
        <Link className="wordmark" href="/" aria-label="NO SUS — Monad Experiment home">
          <span className="wordmark-mark" aria-hidden="true">N</span>
          <span>NO SUS <span className="muted">/ MONAD EXPERIMENT</span></span>
        </Link>
        <nav className="topbar-actions" aria-label="Main navigation">
          <Link className="text-button" href="/">Write a note</Link>
          <Link className="text-button" href="/preview">Try a sample</Link>
        </nav>
      </header>
      <main id="main-content" className="notes-main">{children}</main>
      <footer className="notes-footer">
        <ExperimentBadge compact />
        <Link className="text-button" href="/operator">Technical setup</Link>
      </footer>
    </div>
  );
}
