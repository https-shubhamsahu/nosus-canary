import { ReceiptVerifier } from "@/components/receipt-verifier";

export default async function VerifyPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <ReceiptVerifier dropId={id} />;
}
