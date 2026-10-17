import { createFileRoute, Link } from "@tanstack/react-router";
import { X } from "lucide-react";
import { getJob, getCompany, formatMoney } from "@/lib/data";
import { useStore, toggleCompare } from "@/lib/store";
import {
  PageHeader,
  SafetyIndicator,
  MatchMeter,
  VerifyBadge,
  EmptyState,
} from "@/components/sr/ui";

export const Route = createFileRoute("/compare")({
  head: () => ({
    meta: [
      { title: "Compare jobs — SafeRata" },
      { name: "description", content: "Compare salary, fees, visa and safety side by side." },
      { property: "og:title", content: "Compare jobs — SafeRata" },
      { property: "og:description", content: "Side-by-side comparison of overseas job offers." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Compare,
});

function Compare() {
  const ids = useStore((s) => s.compare);
  const list = ids.map(getJob).filter((j): j is NonNullable<typeof j> => !!j);
  const rows: [string, (j: (typeof list)[0]) => React.ReactNode][] = [
    [
      "Salary",
      (j) => (
        <span className="font-mono">
          {formatMoney(j.salary, j.currency)}
          <br />
          <span className="text-xs text-muted-foreground">
            ≈ LKR {j.salaryLkr.toLocaleString("en-US")}
          </span>
        </span>
      ),
    ],
    [
      "Fee to you",
      (j) =>
        j.fee === null
          ? "Not disclosed"
          : j.fee === 0
            ? "None"
            : `LKR ${j.fee.toLocaleString("en-US")}`,
    ],
    ["Visa", (j) => <span className={j.visaOk ? "" : "font-semibold text-risk"}>{j.visa}</span>],
    ["Contract", (j) => j.contract],
    ["Accommodation", (j) => j.accommodation],
    ["Safety", (j) => <SafetyIndicator risk={j.risk} />],
    ["Match", (j) => <MatchMeter value={j.match} />],
    ["Agency licence", (j) => <VerifyBadge state={getCompany(j.agencyId)!.licenceState} />],
  ];
  return (
    <div>
      <PageHeader eyebrow="Compare" title="Side by side." />
      {list.length === 0 ? (
        <EmptyState
          title="Nothing to compare yet"
          body="Open a job and press Compare. You can add up to three."
          action={
            <Link
              to="/"
              className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground"
            >
              Browse jobs
            </Link>
          }
        />
      ) : (
        <div className="overflow-x-auto rounded-xl border border-border bg-card">
          <table className="w-full min-w-[640px] text-sm">
            <thead>
              <tr className="border-b border-border">
                <th className="w-36" />
                {list.map((j) => (
                  <th key={j.id} className="p-4 text-left align-top">
                    <div className="flex items-start justify-between gap-2">
                      <Link
                        to="/jobs/$id"
                        params={{ id: j.id }}
                        className="font-display text-lg font-bold leading-tight hover:text-primary"
                      >
                        {j.role}
                      </Link>
                      <button
                        onClick={() => toggleCompare(j.id)}
                        aria-label={`Remove ${j.role}`}
                        className="text-muted-foreground hover:text-foreground"
                      >
                        <X className="h-4 w-4" />
                      </button>
                    </div>
                    <p className="text-xs font-normal text-muted-foreground">
                      {j.city}, {j.country}
                    </p>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {rows.map(([label, fn]) => (
                <tr key={label}>
                  <th className="eyebrow p-4 text-left align-top">{label}</th>
                  {list.map((j) => (
                    <td key={j.id} className="p-4 align-top">
                      {fn(j)}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
