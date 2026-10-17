import { createFileRoute, Link } from "@tanstack/react-router";
import { companies, jobs } from "@/lib/data";
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
        <SimulatedTag />
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
            {companies.map((c) => (
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
                  {jobs.filter((j) => j.agencyId === c.id || j.employerId === c.id).length}
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
