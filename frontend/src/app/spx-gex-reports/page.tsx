import { redirect } from "next/navigation";

export default function LegacySPXGEXReportsPage() {
  redirect("/trading-signal-reports?strategy=spx-gex");
}
