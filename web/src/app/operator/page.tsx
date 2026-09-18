import Link from "next/link";
import { HomeDashboard } from "@/components/home-dashboard";

export default function OperatorPage() {
  return <><div className="operator-banner">Developer setup · <Link href="/">Back to private notes</Link></div><HomeDashboard /></>;
}
