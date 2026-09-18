export const NOTE_LIMIT = 500;
export const EXPIRY_OPTIONS = [
  { hours: 1, label: "1 hour" },
  { hours: 24, label: "24 hours" },
  { hours: 168, label: "7 days" },
] as const;

export type NoteDraft = { recipientEmail: string; note: string; expiryHours: number };
export type DraftErrors = Partial<Record<keyof NoteDraft, string>>;

export function validateDraft(draft: NoteDraft): DraftErrors {
  const errors: DraftErrors = {};
  const email = draft.recipientEmail.trim();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    errors.recipientEmail = "Enter the email address of the person you want to send this to.";
  }
  if (!draft.note.trim()) errors.note = "Write a short personal test note first.";
  else if (draft.note.length > NOTE_LIMIT) errors.note = `Keep your note under ${NOTE_LIMIT + 1} characters.`;
  if (!EXPIRY_OPTIONS.some((option) => option.hours === draft.expiryHours)) {
    errors.expiryHours = "Choose one of the available expiry times.";
  }
  return errors;
}

export type NoteStatus = "waiting" | "ready" | "accepted" | "expired";
export type NoteSnapshot = {
  recipientReady: boolean;
  acceptedAt: number | null;
  expiresAt: number | null;
};

/** Receipt history survives expiry; expiry controls new unlock requests. */
export function noteStatus(note: NoteSnapshot, now: number): NoteStatus {
  if (note.expiresAt !== null && now >= note.expiresAt) return "expired";
  if (note.acceptedAt !== null) return "accepted";
  return note.recipientReady ? "ready" : "waiting";
}

export const STATUS_LABELS: Record<NoteStatus, string> = {
  waiting: "Waiting for recipient setup",
  ready: "Ready to accept",
  accepted: "Accepted",
  expired: "Expired",
};
