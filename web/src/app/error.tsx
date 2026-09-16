"use client";

import { useEffect } from "react";

export default function GlobalError({ reset }: { error: Error; reset: () => void }) {
  useEffect(() => {
    // Error contents may include wallet/provider data, so they are deliberately not logged.
  }, []);

  return (
    <main className="simple-page">
      <p className="eyebrow">SAFE FAILURE</p>
      <h1>The experiment paused before handling any note.</h1>
      <button className="primary-button" onClick={reset} type="button">Try again</button>
    </main>
  );
}
