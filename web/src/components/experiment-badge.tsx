type ExperimentBadgeProps = {
  compact?: boolean;
};

export function ExperimentBadge({ compact = false }: ExperimentBadgeProps) {
  return (
    <p className={compact ? "experiment-badge compact" : "experiment-badge"}>
      <span aria-hidden="true">◆</span>
      Experimental · Monad Testnet · Personal test data only
    </p>
  );
}
