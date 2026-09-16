type LockOrbProps = {
  state?: "sealed" | "awaiting" | "unlocked";
};

export function LockOrb({ state = "sealed" }: LockOrbProps) {
  const label =
    state === "unlocked"
      ? "A confirmed recipient wallet can request decryption"
      : state === "awaiting"
        ? "Waiting for a recipient wallet acknowledgement"
        : "Encrypted drop is sealed";

  return (
    <div className={`lock-orb ${state}`} aria-label={label} role="img">
      <span className="orb-axis orb-axis-horizontal" aria-hidden="true" />
      <span className="orb-axis orb-axis-vertical" aria-hidden="true" />
      <span className="orb-ring ring-one" aria-hidden="true" />
      <span className="lock-shackle" aria-hidden="true" />
      <span className="lock-body" aria-hidden="true">
        <span className="lock-keyhole" />
      </span>
      <span className="orb-status">{state}</span>
    </div>
  );
}
