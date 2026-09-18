import type { Metadata } from "next";

import "./globals.css";

export const metadata: Metadata = {
  title: "NO SUS — Monad Experiment",
  description: "Private notes with wallet acceptance receipts. An experimental Monad Testnet experience.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
