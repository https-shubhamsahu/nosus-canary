import assert from "node:assert/strict";
import { test } from "node:test";
import { validateDraft, noteStatus } from "../src/features/private-notes/note-state.ts";
import { newSample, restoreSample, sampleReducer } from "../src/features/private-notes/sample-state.ts";

test("draft validation rejects absent recipient, whitespace notes, oversized notes, and unsupported expiry", () => {
  assert.deepEqual(validateDraft({ recipientEmail: "friend@example.com", note: "Picnic at four", expiryHours: 24 }), {});
  assert.ok(validateDraft({ recipientEmail: "friend", note: "   ", expiryHours: 2 }).recipientEmail);
  assert.ok(validateDraft({ recipientEmail: "friend@example.com", note: "   ", expiryHours: 24 }).note);
  assert.ok(validateDraft({ recipientEmail: "friend@example.com", note: "a".repeat(501), expiryHours: 24 }).note);
  assert.ok(validateDraft({ recipientEmail: "friend@example.com", note: "Test", expiryHours: -1 }).expiryHours);
});

test("expiry blocks new access while retaining the original acceptance timestamp", () => {
  const note = { recipientReady: true, acceptedAt: 50, expiresAt: 100 };
  assert.equal(noteStatus(note, 99), "accepted");
  assert.equal(noteStatus(note, 100), "expired");
  assert.equal(note.acceptedAt, 50);
  assert.equal(noteStatus({ recipientReady: false, acceptedAt: null, expiresAt: null }, 100), "waiting");
});

test("sample cannot accept before setup or acknowledge twice, and refresh restores acceptance", () => {
  const invited = newSample(1_000);
  assert.equal(sampleReducer(invited, { type: "accept", now: 2_000 }), invited);
  const ready = sampleReducer(invited, { type: "verify", now: 2_000 });
  const accepted = sampleReducer(ready, { type: "accept", now: 3_000 });
  assert.equal(sampleReducer(accepted, { type: "accept", now: 4_000 }), accepted);
  assert.deepEqual(restoreSample(JSON.stringify(accepted), 5_000), accepted);
  const expired = sampleReducer(ready, { type: "expire", now: 3_000 });
  assert.equal(sampleReducer(expired, { type: "accept", now: 3_000 }), expired);
});

test("malformed or inconsistent saved sample state restarts safely", () => {
  for (const raw of ["broken", "null", '{"version":1,"stage":"accepted","expiresAt":5000,"acceptedAt":null}', '{"version":1,"stage":"ready","expiresAt":5000,"acceptedAt":10}']) {
    assert.deepEqual(restoreSample(raw, 1_000), newSample(1_000));
  }
});
