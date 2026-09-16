"use client";

import { useState } from "react";

import { connectInjectedWallet } from "@/lib/wallet";

function shortAddress(address: string) {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}

export function WalletControl() {
  const [address, setAddress] = useState<string>();
  const [error, setError] = useState<string>();
  const [connecting, setConnecting] = useState(false);

  async function connect() {
    setConnecting(true);
    setError(undefined);
    try {
      const wallet = await connectInjectedWallet();
      setAddress(wallet.address);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Wallet connection was cancelled.");
    } finally {
      setConnecting(false);
    }
  }

  return (
    <div className="wallet-control">
      <button className="wallet-button" onClick={connect} disabled={connecting} type="button">
        <span className="wallet-pulse" aria-hidden="true" />
        {connecting ? "Connecting…" : address ? shortAddress(address) : "Connect wallet"}
      </button>
      {error ? <p className="inline-error" role="alert">{error}</p> : null}
    </div>
  );
}
