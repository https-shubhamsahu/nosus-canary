import type { Metadata } from "next";

import "./globals.css";

export const metadata: Metadata = {
  title: "NO SUS — Monad Experiment",
  description: "A testnet-only one-time encrypted-drop experiment.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
