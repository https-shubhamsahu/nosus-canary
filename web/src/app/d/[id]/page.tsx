import { RecipientConsole } from "@/components/recipient-console";

export default async function RecipientPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <RecipientConsole dropId={id} />;
}
