"use client";

import { useEffect, useState } from "react";

type ReceiptWallItem = {
  id: string;
  senderWallet: string;
  recipientWallet: string | null;
  openerWallet: string | null;
  sealedTxHash: string | null;
  openedTxHash: string | null;
  createdAt: string;
  openedAt: string | null;
};

function abbreviated(value: string | null) {
  if (!value) return "Open recipient";
  return `${value.slice(0, 6)}…${value.slice(-4)}`;
}

export function LiveReceiptWall() {
  const [items, setItems] = useState<ReceiptWallItem[]>([]);
  const [status, setStatus] = useState("Waiting for the isolated backend.");

  useEffect(() => {
    let stopped = false;
    async function refresh() {
      try {
        const response = await fetch("/api/wall", { cache: "no-store" });
        if (!response.ok) {
          const body = (await response.json()) as { error?: string };
          if (!stopped) setStatus(body.error ?? "Receipt Wall is not configured.");
          return;
        }
        const body = (await response.json()) as { items: ReceiptWallItem[] };
        if (!stopped) {
          setItems(body.items);
          setStatus(body.items.length ? "Streaming the latest recorded receipts." : "No recorded receipts yet.");
        }
      } catch {
        if (!stopped) setStatus("Receipt Wall cannot reach the local backend yet.");
      }
    }
    void refresh();
    const timer = window.setInterval(refresh, 12_000);
    return () => {
      stopped = true;
      window.clearInterval(timer);
    };
  }, []);

  return (
    <section className="receipt-wall" aria-labelledby="receipt-wall-title">
      <div className="wall-topline">
        <div>
          <p className="eyebrow">Live receipt wall / 02</p>
          <h2 id="receipt-wall-title">A signal, not surveillance.</h2>
        </div>
        <span className="live-indicator"><i aria-hidden="true" /> LIVE</span>
      </div>
      <p className="wall-status" aria-live="polite">{status}</p>
      {items.length ? (
        <ol className="receipt-list">
          {items.map((item) => (
            <li key={item.id}>
              <span className={item.openedAt ? "receipt-state opened" : "receipt-state sealed"}>
                {item.openedAt ? "OPENED" : "SEALED"}
              </span>
              <code>{item.id.slice(0, 12)}…</code>
              <span>{abbreviated(item.senderWallet)} → {abbreviated(item.openerWallet ?? item.recipientWallet)}</span>
            </li>
          ))}
        </ol>
      ) : (
        <div className="empty-wall">
          <span className="empty-glyph" aria-hidden="true">◌</span>
          <p>Receipts appear here only after the separate backend records real testnet events.</p>
        </div>
      )}
    </section>
  );
}
