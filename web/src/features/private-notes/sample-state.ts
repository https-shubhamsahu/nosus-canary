/** Only the /preview walkthrough uses this state. Never use it as authentication. */
export type SampleState = {
  version: 1;
  stage: "invited" | "ready" | "accepted";
  acceptedAt: number | null;
  expiresAt: number;
};
export type SampleAction = { type: "verify" | "accept" | "expire"; now: number };

export function newSample(now: number): SampleState {
  return { version: 1, stage: "invited", acceptedAt: null, expiresAt: now + 86_400_000 };
}

export function sampleReducer(state: SampleState, action: SampleAction): SampleState {
  if (action.type === "expire") return { ...state, expiresAt: action.now };
  if (action.now >= state.expiresAt) return state;
  if (action.type === "verify" && state.stage === "invited") return { ...state, stage: "ready" };
  if (action.type === "accept" && state.stage === "ready") return { ...state, stage: "accepted", acceptedAt: action.now };
  return state;
}

/** Reject malformed or internally inconsistent saved demo state. No user data is saved. */
export function restoreSample(raw: string | null, now: number): SampleState {
  try {
    const value: unknown = JSON.parse(raw ?? "null");
    if (typeof value !== "object" || value === null) return newSample(now);
    const sample = value as Partial<SampleState>;
    if (sample.version !== 1 || !["invited", "ready", "accepted"].includes(sample.stage ?? "")) return newSample(now);
    if (typeof sample.expiresAt !== "number" || !Number.isFinite(sample.expiresAt)) return newSample(now);
    if (sample.stage === "accepted") {
      if (typeof sample.acceptedAt !== "number" || !Number.isFinite(sample.acceptedAt) || sample.acceptedAt > now) return newSample(now);
    } else if (sample.acceptedAt !== null) return newSample(now);
    return { version: 1, stage: sample.stage!, acceptedAt: sample.acceptedAt!, expiresAt: sample.expiresAt };
  } catch { return newSample(now); }
}
