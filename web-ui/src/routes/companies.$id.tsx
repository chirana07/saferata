import { createFileRoute, Link, notFound } from "@tanstack/react-router";
import { useState } from "react";
import { ArrowLeft, Flag } from "lucide-react";
import { toast } from "sonner";
import { getCompany, jobs, type Review } from "@/lib/data";
import { apiAddReview } from "@/lib/api";
import { setState, useStore } from "@/lib/store";
import { VerifyBadge, SafetyIndicator, SimulatedTag, EmptyState } from "@/components/sr/ui";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/companies/$id")({
  loader: ({ params }) => {
    const company = getCompany(params.id);
    if (!company) throw notFound();
    return { company };
  },
  head: ({ loaderData }) => ({
    meta: [
      { title: `${loaderData?.company.name ?? "Company"} — SafeRata intelligence` },
      {
        name: "description",
        content: `Licence status, listings and moderated reports for ${loaderData?.company.name}.`,
      },
      { property: "og:title", content: `${loaderData?.company.name} — SafeRata` },
      {
        property: "og:description",
        content: "Evidence-graded company intelligence for overseas jobs.",
      },
      { property: "og:type", content: "profile" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  notFoundComponent: () => (
    <p className="py-20 text-center">
      Company not found.{" "}
      <Link to="/companies" className="text-primary">
        All companies
      </Link>
    </p>
  ),
  component: CompanyPage,
});

const CATS: Review["category"][] = [
  "Unpaid salary",
  "Contract changes",
  "Excessive fees",
  "Misleading terms",
  "Positive experience",
];
const NO_REVIEWS: Review[] = [];

function CompanyPage() {
  const { company: c } = Route.useLoaderData();
  const extra = useStore((s) => s.reviews[c.id] ?? NO_REVIEWS);
  const reviews = [...extra, ...c.reviews];
  const listings = jobs.filter((j) => j.agencyId === c.id || j.employerId === c.id);
  const [form, setForm] = useState<{ category: Review["category"]; role: string; text: string }>({
    category: "Unpaid salary",
    role: "",
    text: "",
  });
  const [mode, setMode] = useState<"report" | "correction" | null>(null);

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (form.text.trim().length < 20) {
      toast.error("Please describe what happened in at least 20 characters.");
      return;
    }
    const r: Review = {
      id: `u${Date.now()}`,
      date: new Date().toISOString().slice(0, 10),
      category: mode === "correction" ? "Misleading terms" : form.category,
      status: "Under review",
      evidence: "Unsubstantiated",
      role: form.role || "Not stated",
      text: (mode === "correction" ? "[Correction request] " : "") + form.text,
    };
    setState((s) => ({ ...s, reviews: { ...s.reviews, [c.id]: [r, ...(s.reviews[c.id] ?? [])] } }));

    // Send to live Jac backend if an associated job exists
    const associatedJob = listings[0];
    if (associatedJob) {
      apiAddReview({
        job_id: associatedJob.id,
        author: form.role || "Anonymous Worker",
        kind: form.category === "Positive experience" ? "positive" : "fraud",
        text: form.text,
        evidence: `Category: ${form.category}`,
      }).then(({ result, error }) => {
        if (result && !error) {
          toast.success("Live AddReview processed", {
            description: "Review Verifier evaluated report and updated graph.",
          });
        } else {
          toast.success("Submitted for moderation", {
            description: "Saved in this browser (backend offline).",
          });
        }
      });
    } else {
      toast.success("Submitted for moderation", {
        description: "Saved in this browser only (demo).",
      });
    }

    setForm({ category: "Unpaid salary", role: "", text: "" });
    setMode(null);
  };

  const counts = CATS.slice(0, 4).map((k) => ({
    k,
    n: reviews.filter((r) => r.category === k).length,
  }));

  return (
    <div>
      <Link
        to="/companies"
        className="inline-flex items-center gap-1 text-sm font-semibold text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="h-4 w-4" /> Companies
      </Link>
      <header className="mt-6 grid gap-6 border-b border-border pb-8 lg:grid-cols-[1fr_340px]">
        <div>
          <p className="eyebrow">
            {c.type} · {c.location}
            {c.founded ? ` · since ${c.founded}` : ""}
          </p>
          <h1 className="mt-2 text-4xl font-extrabold leading-[0.95] md:text-6xl">{c.name}</h1>
          <p className="mt-4 max-w-2xl text-muted-foreground">{c.summary}</p>
        </div>
        <dl className="rounded-xl border border-border bg-card p-5 text-sm shadow-card">
          <div className="flex items-center justify-between">
            <dt className="eyebrow">Licence</dt>
            <SimulatedTag>Simulated registry</SimulatedTag>
          </div>
          <dd className="mt-2 flex items-center gap-2 font-mono">
            {c.licence ?? "Not disclosed"} <VerifyBadge state={c.licenceState} />
          </dd>
          <dt className="eyebrow mt-4">Last checked</dt>
          <dd className="mt-1 font-mono">{c.lastChecked ?? "Never"}</dd>
          <dt className="eyebrow mt-4">Related entities</dt>
          <dd className="mt-1 flex flex-wrap gap-1.5">
            {c.related.map((r) => {
              const rc = getCompany(r);
              return rc ? (
                <Link
                  key={r}
                  to="/companies/$id"
                  params={{ id: r }}
                  className="rounded border border-border px-2 py-0.5 text-xs font-medium hover:border-primary"
                >
                  {rc.name}
                </Link>
              ) : null;
            })}
          </dd>
        </dl>
      </header>

      <div className="grid gap-10 py-8 lg:grid-cols-[1fr_1.4fr]">
        <section>
          <h2 className="text-xl font-bold">Listings</h2>
          <ul className="mt-3 divide-y divide-border rounded-xl border border-border bg-card">
            {listings.length ? (
              listings.map((j) => (
                <li key={j.id}>
                  <Link
                    to="/jobs/$id"
                    params={{ id: j.id }}
                    className="flex items-center justify-between gap-3 px-4 py-3 hover:bg-muted"
                  >
                    <span>
                      <span className="block text-sm font-semibold">{j.role}</span>
                      <span className="text-xs text-muted-foreground">
                        {j.city} · {j.posted}
                      </span>
                    </span>
                    <SafetyIndicator risk={j.risk} compact />
                  </Link>
                </li>
              ))
            ) : (
              <li className="px-4 py-3 text-sm text-muted-foreground">No listings in demo data.</li>
            )}
          </ul>

          <h2 className="mt-8 text-xl font-bold">Report categories</h2>
          <dl className="mt-3 grid grid-cols-2 gap-px overflow-hidden rounded-xl border border-border bg-border">
            {counts.map(({ k, n }) => (
              <div key={k} className="bg-card p-4">
                <dd className={cn("font-display text-3xl font-bold", n > 0 && "text-risk")}>{n}</dd>
                <dt className="text-xs text-muted-foreground">{k}</dt>
              </div>
            ))}
          </dl>
          {c.agencyResponse && (
            <blockquote className="mt-6 border-l-2 border-primary pl-4 text-sm">
              <p className="eyebrow mb-1">Agency response</p>
              {c.agencyResponse}
            </blockquote>
          )}
        </section>

        <section>
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h2 className="text-xl font-bold">Moderated worker reports</h2>
            <div className="flex gap-2">
              <button
                onClick={() => setMode(mode === "report" ? null : "report")}
                className="inline-flex items-center gap-1.5 rounded-md bg-primary px-3 py-2 text-xs font-semibold text-primary-foreground"
              >
                <Flag className="h-3.5 w-3.5" /> Submit report
              </button>
              <button
                onClick={() => setMode(mode === "correction" ? null : "correction")}
                className="rounded-md border border-border bg-card px-3 py-2 text-xs font-semibold"
              >
                Request correction
              </button>
            </div>
          </div>
          <p className="mt-1 text-xs text-muted-foreground">
            Allegations are shown with their evidence grade and status. An unresolved report is not
            an established fact.
          </p>

          {mode && (
            <form
              onSubmit={submit}
              className="mt-4 space-y-3 rounded-xl border border-primary/40 bg-card p-4 rise-in"
            >
              <p className="text-sm font-semibold">
                {mode === "report"
                  ? "Share your experience"
                  : "Request a correction to this profile"}
              </p>
              {mode === "report" && (
                <div className="grid gap-3 sm:grid-cols-2">
                  <label className="text-xs font-semibold">
                    Category
                    <select
                      value={form.category}
                      onChange={(e) =>
                        setForm({ ...form, category: e.target.value as Review["category"] })
                      }
                      className="mt-1 h-10 w-full rounded-md border border-input bg-card px-2 text-sm font-normal"
                    >
                      {CATS.map((k) => (
                        <option key={k}>{k}</option>
                      ))}
                    </select>
                  </label>
                  <label className="text-xs font-semibold">
                    Your role (optional)
                    <input
                      value={form.role}
                      onChange={(e) => setForm({ ...form, role: e.target.value })}
                      className="mt-1 h-10 w-full rounded-md border border-input bg-card px-2 text-sm font-normal"
                    />
                  </label>
                </div>
              )}
              <label className="block text-xs font-semibold">
                What happened?
                <textarea
                  value={form.text}
                  onChange={(e) => setForm({ ...form, text: e.target.value })}
                  rows={3}
                  className="mt-1 w-full rounded-md border border-input bg-card p-2 text-sm font-normal"
                />
              </label>
              <p className="text-xs text-muted-foreground">
                Don't include your NIC, passport number or phone number.
              </p>
              <button className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground">
                Submit for moderation
              </button>
            </form>
          )}

          {reviews.length === 0 ? (
            <div className="mt-4">
              <EmptyState
                title="No reports yet"
                body="No worker has reported on this company. That is not evidence either way."
              />
            </div>
          ) : (
            <ol className="mt-4 border-l border-border">
              {reviews.map((r) => (
                <li key={r.id} className="relative pb-6 pl-6">
                  <span
                    className={cn(
                      "absolute -left-[5px] top-1.5 h-2.5 w-2.5 rounded-sm",
                      r.category === "Positive experience"
                        ? "bg-safe"
                        : r.status === "Resolved"
                          ? "bg-sky"
                          : "bg-caution",
                    )}
                  />
                  <div className="flex flex-wrap items-center gap-2 text-xs">
                    <span className="font-mono text-muted-foreground">{r.date}</span>
                    <span className="font-semibold">{r.category}</span>
                    <span className="rounded bg-muted px-1.5 py-0.5">{r.status}</span>
                    <span className="rounded border border-border px-1.5 py-0.5">
                      Evidence: {r.evidence}
                    </span>
                  </div>
                  <p className="mt-1.5 text-sm">{r.text}</p>
                  <p className="mt-1 text-xs text-muted-foreground">— {r.role}</p>
                </li>
              ))}
            </ol>
          )}
        </section>
      </div>
    </div>
  );
}
