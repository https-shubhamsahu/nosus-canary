import Link from "next/link";

import { ExperimentBadge } from "@/components/experiment-badge";

export default function NotFound() {
  return (
    <main className="simple-page">
      <ExperimentBadge compact />
      <p className="eyebrow">404 / DROP NOT FOUND</p>
      <h1>This link does not identify a recorded experiment drop.</h1>
      <Link className="primary-button" href="/">Back to the experiment</Link>
    </main>
  );
}
