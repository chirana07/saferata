import { createFileRoute, Link } from "@tanstack/react-router";
import { useState, useEffect } from "react";
import {
  companies as initialCompanies,
  jobs as demoJobs,
  type Company,
  registerLiveAgencies,
} from "@/lib/data";
import { apiListAgencies } from "@/lib/api";
import { PageHeader, VerifyBadge, SimulatedTag } from "@/components/sr/ui";

export const Route = createFileRoute("/companies/")({
  head: () => ({
    meta: [
      { title: "Company intelligence — SafeRata" },
      {
        name: "description",
        content:
          "Licence status, listings and moderated worker reports for recruitment agencies and employers.",
      },
      { property: "og:title", content: "Company intelligence — SafeRata" },
      {
        property: "og:description",
        content: "Research the agencies and employers behind overseas jobs.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Companies,
});

function Companies() {
  const [companyList, setCompanyList] = useState<Company[]>(initialCompanies ?? []);
  const [isLive, setIsLive] = useState(false);

  useEffect(() => {
    let active = true;
    apiListAgencies().then(({ agencies }) => {
      if (active && agencies && agencies.length > 0) {
        setIsLive(true);
        // Map backend agencies into UI companies format
        const liveCompanies: Company[] = agencies.map((a) => ({
          id: `agency-${a.licence_no.replace(/[^a-zA-Z0-9_-]/g, "_")}`,
          name: a.name,
          type: "Recruitment agency" as const,
          location: "Sri Lanka",
          licence: a.licence_no,
          licenceState: "verified" as const,
          lastChecked: a.checked_at
            ? a.checked_at.slice(0, 10)
            : new Date().toISOString().slice(0, 10),
          summary: `SLBFE Licensed Agency #${a.licence_no}. Contact: ${a.phones.join(", ") || a.email || "Official register"}`,
          related: [],
          reviews: a.warnings.map((w, idx) => ({
            id: `warn-${idx}`,
            date: new Date().toISOString().slice(0, 10),
            category: "Misleading terms" as const,
            status: "Moderated" as const,
            evidence: "Documented" as const,
            text: w,
            role: "Applicant report",
          })),
        }));

        // Register live agencies in global cache so details page can resolve them
        registerLiveAgencies(liveCompanies);

        // Merge with initial demo companies to prevent loss of existing data
        const merged = [...liveCompanies];
        for (const c of initialCompanies) {
          if (!merged.some((m) => m.id === c.id || m.licence === c.licence)) {
            merged.push(c);
          }
        }
        setCompanyList(merged);
      }
    });
    return () => {
      active = false;
    };
  }, []);
  return (
    <div>
      <PageHeader
        eyebrow="Company intelligence"
        title={
          <>
            Know who you're
            <br />
            dealing with.
          </>
        }
      >
        {isLive ? (
          <span className="rounded bg-safe-soft px-2 py-0.5 text-xs font-semibold text-safe">
            ● Live SLBFE register
          </span>
        ) : (
          <SimulatedTag />
        )}
      </PageHeader>
      <div className="overflow-x-auto rounded-xl border border-border bg-card">
        <table className="w-full min-w-[640px] text-sm">
          <thead className="eyebrow border-b border-border text-left">
            <tr>
              <th className="px-4 py-3">Name</th>
              <th>Type</th>
              <th>Licence / registration</th>
              <th>Listings</th>
              <th className="pr-4">Reports</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {companyList.map((c) => (
              <tr key={c.id} className="hover:bg-muted">
                <td className="px-4 py-3">
                  <Link
                    to="/companies/$id"
                    params={{ id: c.id }}
                    className="font-semibold hover:text-primary"
                  >
                    {c.name}
                  </Link>
                  <p className="text-xs text-muted-foreground">{c.location}</p>
                </td>
                <td className="text-muted-foreground">{c.type}</td>
                <td>
                  <VerifyBadge state={c.licenceState} />
                </td>
                <td className="font-mono">
                  {demoJobs.filter((j) => j.agencyId === c.id || j.employerId === c.id).length}
                </td>
                <td className="pr-4 font-mono">{c.reviews.length}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
