import { NextResponse } from "next/server";

import { BackendNotConfiguredError, getExperimentAdmin } from "@/lib/server/supabase";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const { data, error } = await getExperimentAdmin()
      .from("experiment_drops")
      .select("id,sender_wallet,recipient_wallet,opener_wallet,sealed_tx_hash,opened_tx_hash,created_at,opened_at")
      .order("created_at", { ascending: false })
      .limit(40);

    if (error) throw error;
    return NextResponse.json({
      items: (data ?? []).map((drop) => ({
        id: drop.id,
        senderWallet: drop.sender_wallet,
        recipientWallet: drop.recipient_wallet,
        openerWallet: drop.opener_wallet,
        sealedTxHash: drop.sealed_tx_hash,
        openedTxHash: drop.opened_tx_hash,
        createdAt: drop.created_at,
        openedAt: drop.opened_at,
      })),
    });
  } catch (error) {
    const message =
      error instanceof BackendNotConfiguredError
        ? error.message
        : "The Receipt Wall is temporarily unavailable.";
    return NextResponse.json({ error: message }, { status: 503 });
  }
}
