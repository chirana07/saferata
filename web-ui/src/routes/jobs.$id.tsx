import { createFileRoute, Link, notFound } from "@tanstack/react-router";
import { ArrowLeft, Info, MessageSquare } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import { getJob, getCompany, jobs, formatMoney } from "@/lib/data";
import {
  SafetyIndicator,
  MatchMeter,
  SaveButton,
  CompareToggle,
  CountryTag,
  VerifyBadge,
  FindingItem,
  SimulatedTag,
} from "@/components/sr/ui";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";

export const Route = createFileRoute("/jobs/$id")({
  loader: async ({ params }) => {
    let job = getJob(params.id);
    if (!job) {
      // Direct navigation or refresh on a live backend job
      try {
        const { apiListJobs } = await import("@/lib/api");
        const { backendJobToUiJob, registerLiveJobs } = await import("@/lib/data");
        const { jobs: backendJobs } = await apiListJobs();
        if (backendJobs && backendJobs.length > 0) {
          const uiJobs = backendJobs.map(backendJobToUiJob);
          registerLiveJobs(uiJobs);
          job = getJob(params.id);
        }
      } catch {
        /* fallback to check below */
      }
    }
    if (!job) throw notFound();
    return { job };
  },
  head: ({ loaderData }) => ({
    meta: [
      { title: `${loaderData?.job.role ?? "Job"} in ${loaderData?.job.city ?? ""} — SafeRata` },
      {
        name: "description",
        content: `Salary, visa, fees and evidence-backed safety findings for ${loaderData?.job.role}.`,
      },
      { property: "og:title", content: `${loaderData?.job.role} — SafeRata` },
      {
        property: "og:description",
        content: "Transparent safety assessment, separate from your personal match.",
      },
      { property: "og:type", content: "article" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  notFoundComponent: () => (
    <p className="py-20 text-center">
      This job no longer exists.{" "}
      <Link to="/" className="text-primary">
        Back to Discover
      </Link>
    </p>
  ),
  component: JobDetail,
});

function Section({ n, title, children }: { n: string; title: string; children: React.ReactNode }) {
  return (
    <section className="grid gap-4 border-t border-border py-8 md:grid-cols-[180px_1fr]">
      <div>
        <p className="font-mono text-xs text-muted-foreground">{n}</p>
        <h2 className="mt-1 text-xl font-bold">{title}</h2>
      </div>
      <div>{children}</div>
    </section>
  );
}

function JobDetail() {
  const { job } = Route.useLoaderData();
  const agency = getCompany(job.agencyId);
  const employer = getCompany(job.employerId);
  const [enquire, setEnquire] = useState(false);
  const rate = job.salary > 0 ? job.salaryLkr / job.salary : 1;
  const deductionsLocal = job.deductions?.reduce((s, d) => s + d.amount, 0) || 0;
  const takeHome = job.salary - deductionsLocal;
  const others = jobs.filter((j) => j.agencyId === job.agencyId && j.id !== job.id);

  return (
    <article>
      <Link
        to="/"
        className="inline-flex items-center gap-1 text-sm font-semibold text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="h-4 w-4" /> Discover
      </Link>

      <header className="mt-6 grid gap-8 lg:grid-cols-[1fr_320px]">
        <div>
          <CountryTag code={job.flag} city={job.city} country={job.country} />
          <h1 className="mt-3 text-4xl font-extrabold leading-[0.95] md:text-6xl">{job.role}</h1>
          <p className="mt-4 text-sm text-muted-foreground">
            <Link
              to="/companies/$id"
              params={{ id: employer.id }}
              className="font-semibold text-foreground underline-offset-4 hover:underline"
            >
              {employer.name}
            </Link>{" "}
            via{" "}
            <Link
              to="/companies/$id"
              params={{ id: agency.id }}
              className="font-semibold text-foreground underline-offset-4 hover:underline"
            >
              {agency.name}
            </Link>{" "}
            · {job.contract} · posted {job.posted}
          </p>
          <div className="mt-5 flex flex-wrap gap-2">
            <SaveButton id={job.id} />
            <CompareToggle id={job.id} />
            <button
              onClick={() => setEnquire(true)}
              className="inline-flex h-9 items-center gap-1.5 rounded-md bg-primary px-3 text-sm font-semibold text-primary-foreground hover:bg-primary-deep"
            >
              <MessageSquare className="h-4 w-4" /> Enquire
            </button>
          </div>
        </div>
        <div className="rounded-xl border border-border bg-card p-5 shadow-card">
          <p className="eyebrow">Monthly salary</p>
          <p className="mt-1 font-display text-4xl font-extrabold">
            {formatMoney(job.salary, job.currency)}
          </p>
          <p className="text-xs text-muted-foreground">
            ≈ LKR {job.salaryLkr.toLocaleString("en-US")} at demo rate
          </p>
          <div className="mt-4 space-y-3 border-t border-border pt-4">
            <div>
              <p className="eyebrow mb-1">Safety assessment</p>
              <SafetyIndicator risk={job.risk} />
            </div>
            <div>
              <p className="eyebrow mb-1">Your match</p>
              <MatchMeter value={job.match} />
            </div>
            <div>
              <p className="eyebrow mb-1">Status</p>
              <VerifyBadge state={job.verification} prefix="Listing" />
            </div>
          </div>
        </div>
      </header>

      <p className="mt-8 flex items-start gap-2 rounded-lg border border-caution/50 bg-caution-soft px-4 py-3 text-sm">
        <Info className="mt-0.5 h-4 w-4 shrink-0" /> Verification is not a guarantee of safety.
        Always confirm your contract with the Sri Lanka Bureau of Foreign Employment before paying
        or travelling.
      </p>

      <div className="mt-6">
        <Section n="01" title="Safety findings">
          <div className="mb-2 flex items-center gap-2">
            <SimulatedTag>Simulated analysis</SimulatedTag>
            <span className="text-xs text-muted-foreground">
              Separate from match score. Promotion never changes it.
            </span>
          </div>
          <ul className="rounded-xl border border-border bg-card px-4">
            {job.findings.map((f, i) => (
              <FindingItem key={f.id} f={f} defaultOpen={i === 0} />
            ))}
          </ul>
          <details className="mt-3 text-sm">
            <summary className="cursor-pointer font-semibold">Full job description</summary>
            <p className="mt-2 text-muted-foreground">{job.description}</p>
          </details>
        </Section>

        <Section n="02" title="Pay & deductions">
          <table className="w-full text-sm">
            <tbody className="divide-y divide-border">
              <tr>
                <td className="py-2">Basic salary</td>
                <td className="py-2 text-right font-mono">
                  {formatMoney(job.salary, job.currency)}
                </td>
              </tr>
              {job.deductions.map((d) => (
                <tr key={d.label}>
                  <td className="py-2 text-muted-foreground">− {d.label}</td>
                  <td className="py-2 text-right font-mono">
                    {formatMoney(d.amount, job.currency)}
                  </td>
                </tr>
              ))}
              <tr className="font-semibold">
                <td className="py-2">Estimated take-home</td>
                <td className="py-2 text-right font-mono">
                  {job.deductions.length
                    ? `${formatMoney(takeHome, job.currency)} ≈ LKR ${Math.round(takeHome * rate).toLocaleString("en-US")}`
                    : "Not enough data"}
                </td>
              </tr>
              <tr>
                <td className="py-2">Recruitment fee to you</td>
                <td
                  className={`py-2 text-right font-mono ${job.fee && job.fee > 150000 ? "text-risk font-semibold" : ""}`}
                >
                  {job.fee === null
                    ? "Not disclosed"
                    : job.fee === 0
                      ? "None"
                      : `LKR ${job.fee.toLocaleString("en-US")}`}
                </td>
              </tr>
              <tr>
                <td className="py-2">Accommodation</td>
                <td className="py-2 text-right">{job.accommodation}</td>
              </tr>
            </tbody>
          </table>
        </Section>

        <Section n="03" title="Visa & contract">
          <dl className="grid gap-4 sm:grid-cols-3">
            <div>
              <dt className="eyebrow">Visa</dt>
              <dd className={`mt-1 font-semibold ${job.visaOk ? "" : "text-risk"}`}>{job.visa}</dd>
            </div>
            <div>
              <dt className="eyebrow">Contract</dt>
              <dd className="mt-1 font-semibold">{job.contract}</dd>
            </div>
            <div>
              <dt className="eyebrow">Experience</dt>
              <dd className="mt-1 font-semibold">
                {job.experience ? `${job.experience}+ years` : "None required"}
              </dd>
            </div>
          </dl>
        </Section>

        <Section n="04" title="Why it matches">
          <ul className="space-y-2">
            {job.matchReasons.map((r) => (
              <li key={r} className="flex gap-2 text-sm">
                <span className="mt-2 h-1 w-3 bg-primary" />
                {r}
              </li>
            ))}
          </ul>
          <p className="mt-3 text-xs text-muted-foreground">
            Based on your profile. A high match does not mean a job is safe.
          </p>
        </Section>

        <Section n="05" title="Who's behind it">
          <div className="grid gap-3 sm:grid-cols-2">
            {[agency, employer].map((c) => (
              <Link
                key={c.id}
                to="/companies/$id"
                params={{ id: c.id }}
                className="rounded-xl border border-border bg-card p-4 hover:border-primary/40"
              >
                <p className="eyebrow">{c.type}</p>
                <p className="mt-1 font-semibold">{c.name}</p>
                <p className="mt-1 line-clamp-2 text-xs text-muted-foreground">{c.summary}</p>
                <div className="mt-3 flex items-center justify-between">
                  <VerifyBadge state={c.licenceState} />
                  <span className="text-xs text-muted-foreground">
                    {c.reviews.length} moderated reports
                  </span>
                </div>
              </Link>
            ))}
          </div>
          {others.length > 0 && (
            <p className="mt-4 text-sm">
              Other listings from this agency:{" "}
              {others.map((o, i) => (
                <span key={o.id}>
                  {i > 0 && ", "}
                  <Link to="/jobs/$id" params={{ id: o.id }} className="font-semibold text-primary">
                    {o.role}
                  </Link>
                </span>
              ))}
            </p>
          )}
        </Section>
      </div>

      <Dialog open={enquire} onOpenChange={setEnquire}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Enquire about this job</DialogTitle>
            <DialogDescription>
              Messaging is not connected in this prototype. Copy these questions to ask the agency
              directly.
            </DialogDescription>
          </DialogHeader>
          <ol className="list-decimal space-y-1 pl-5 text-sm">
            <li>Can I see the full contract before paying anything?</li>
            <li>What is the employer's registration number?</li>
            <li>Which fees will I pay, to whom, and will I get a receipt?</li>
          </ol>
          <button
            onClick={() => {
              navigator.clipboard?.writeText(
                "1. Can I see the full contract before paying anything?\n2. What is the employer's registration number?\n3. Which fees will I pay, to whom, and will I get a receipt?",
              );
              toast.success("Questions copied");
              setEnquire(false);
            }}
            className="mt-2 rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground"
          >
            Copy questions
          </button>
        </DialogContent>
      </Dialog>
    </article>
  );
}
