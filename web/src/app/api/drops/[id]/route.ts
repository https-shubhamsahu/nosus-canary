import { NextResponse } from "next/server";

import { isDropId } from "@/lib/drop-id";
import { BackendNotConfiguredError, getExperimentAdmin } from "@/lib/server/supabase";

export const dynamic = "force-dynamic";

export async function GET(_request: Request, context: { params: Promise<{ id: string }> }) {
  const { id } = await context.params;
  if (!isDropId(id)) {
    return NextResponse.json({ error: "Invalid drop identifier." }, { status: 400 });
  }

  try {
    const { data, error } = await getExperimentAdmin()
      .from("experiment_drops")
      .select("id,sender_wallet,recipient_wallet,opener_wallet,ciphertext_digest,expires_at,sealed_tx_hash,opened_tx_hash,created_at,opened_at")
      .eq("id", id.toLowerCase())
      .maybeSingle();
    if (error) throw error;
    if (!data) return NextResponse.json({ error: "Drop not found." }, { status: 404 });

    return NextResponse.json({
      id: data.id,
      senderWallet: data.sender_wallet,
      recipientWallet: data.recipient_wallet,
      openerWallet: data.opener_wallet,
      ciphertextDigest: data.ciphertext_digest,
      expiresAt: data.expires_at,
      sealedTxHash: data.sealed_tx_hash,
      openedTxHash: data.opened_tx_hash,
      createdAt: data.created_at,
      openedAt: data.opened_at,
    });
  } catch (error) {
    const message =
      error instanceof BackendNotConfiguredError
        ? error.message
        : "The verifier backend is temporarily unavailable.";
    return NextResponse.json({ error: message }, { status: 503 });
  }
}
