import Link from "next/link";

import { ExperimentBadge } from "@/components/experiment-badge";
import { LiveReceiptWall } from "@/components/live-receipt-wall";
import { LockOrb } from "@/components/lock-orb";
import { SealConsole } from "@/components/seal-console";
import { WalletControl } from "@/components/wallet-control";

export function HomeDashboard() {
  return (
    <main className="page-shell">
      <nav className="topbar" aria-label="Primary navigation">
        <Link className="wordmark" href="/" aria-label="NO SUS Monad Experiment home">
          <span className="wordmark-mark" aria-hidden="true">N</span>
          <span>NO SUS<span className="muted">/MONAD</span></span>
        </Link>
        <WalletControl />
      </nav>

      <section className="hero-grid" aria-labelledby="hero-title">
        <div className="hero-copy">
          <ExperimentBadge />
          <p className="eyebrow">One acknowledgement. One chance.</p>
          <h1 id="hero-title">The lock only listens after the chain does.</h1>
          <p className="hero-lede">
            A recipient wallet can request a one-time decrypt only after its acknowledgement is
            recorded on Monad Testnet.
          </p>
          <div className="hero-actions">
            <a className="primary-button" href="#seal-title">Explore the flow <span aria-hidden="true">↓</span></a>
            <Link className="text-button" href="/verify/example">View receipt verifier <span aria-hidden="true">↗</span></Link>
          </div>
          <p className="honesty-line">
            An on-chain receipt records a wallet action — not human comprehension, identity,
            screenshot prevention, or legal proof.
          </p>
        </div>
        <div className="hero-orb-wrap">
          <LockOrb state="sealed" />
          <div className="orb-caption"><span>MONAD TESTNET</span><span>THRESHOLD GATE: T1</span></div>
        </div>
      </section>

      <section className="signal-strip" aria-label="Product flow">
        <span><b>01</b> Encrypt in browser</span>
        <span><b>02</b> Seal digest on Monad</span>
        <span><b>03</b> Recipient acknowledges</span>
        <span><b>04</b> Lit checks access</span>
      </section>

      <div className="workspace-grid">
        <SealConsole />
        <LiveReceiptWall />
      </div>
    </main>
  );
}
