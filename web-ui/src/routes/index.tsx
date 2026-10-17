import { createFileRoute, Link } from "@tanstack/react-router";
import { useMemo, useState, useEffect } from "react";
import { Search, SlidersHorizontal, ArrowRight, X } from "lucide-react";
import {
  jobs as demoJobs,
  countries as initialCountries,
  occupations as initialOccupations,
  trustStats,
  getCompany,
  getJob,
  formatMoney,
  backendJobToUiJob,
  registerLiveJobs,
  type Job,
} from "@/lib/data";
import { apiListJobs } from "@/lib/api";
import { useStore, profileCompletion } from "@/lib/store";
import {
  JobCard,
  SafetyIndicator,
  MatchMeter,
  SaveButton,
  CountryTag,
  VerifyBadge,
  EmptyState,
  SimulatedTag,
} from "@/components/sr/ui";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Discover overseas jobs — SafeRata" },
      {
        name: "description",
        content:
          "Overseas jobs for Sri Lankan workers, each with a transparent safety assessment and personal match.",
      },
      { property: "og:title", content: "Discover overseas jobs — SafeRata" },
      { property: "og:description", content: "Your next chapter abroad, with confidence." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Discover,
});

type Sort = "relevance" | "salary" | "recent" | "suitability";
const sel =
  "h-10 rounded-md border border-input bg-card px-3 text-sm font-medium focus:border-primary";

function Discover() {
  const profile = useStore((s) => s.profile);
  const saved = useStore((s) => s.saved);
  const pct = profileCompletion(profile);
  const [jobs, setJobs] = useState<Job[]>(demoJobs ?? []);
  const allJobs = jobs;
  const [isLiveBackend, setIsLiveBackend] = useState(false);
  const [q, setQ] = useState("");
  const [country, setCountry] = useState("");
  const [occ, setOcc] = useState("");
  const [minSal, setMinSal] = useState(0);
  const [exp, setExp] = useState(-1);
  const [ctype, setCtype] = useState("");
  const [verifiedOnly, setVerifiedOnly] = useState(false);
  const [sort, setSort] = useState<Sort>("relevance");
  const [showFilters, setShowFilters] = useState(false);

  useEffect(() => {
    let active = true;
    apiListJobs().then(({ jobs: backendJobs, error }) => {
      if (!active) return;
      if (backendJobs && backendJobs.length > 0) {
        const liveConverted = backendJobs.map(backendJobToUiJob);
        registerLiveJobs(liveConverted);
        // Combine live jobs with demo jobs (live jobs first)
        setJobs([...liveConverted, ...(demoJobs ?? [])]);
        setIsLiveBackend(true);
      }
    });
    return () => {
      active = false;
    };
  }, []);

  const countries = useMemo(() => Array.from(new Set(allJobs.map((j) => j.country))), [allJobs]);
  const occupations = useMemo(
    () => Array.from(new Set(allJobs.map((j) => j.occupation))),
    [allJobs],
  );

  const featured = allJobs.find((j) => j.featured) || allJobs[0];
  const results = useMemo(() => {
    const term = q.trim().toLowerCase();
    const r = allJobs.filter((j) => {
      if (
        term &&
        !`${j.role} ${j.country} ${j.city} ${j.occupation} ${j.description}`

          .toLowerCase()
          .includes(term)
      )
        return false;
      if (country && j.country !== country) return false;
      if (occ && j.occupation !== occ) return false;
      if (j.salaryLkr < minSal) return false;
      if (exp >= 0 && j.experience > exp) return false;
      if (ctype && j.contractType !== ctype) return false;
      if (verifiedOnly && getCompany(j.agencyId)?.licenceState !== "verified") return false;
      return true;
    });
    const by: Record<Sort, (a: Job, b: Job) => number> = {
      relevance: (a, b) =>
        b.match - a.match + (a.risk === "critical" ? 30 : 0) - (b.risk === "critical" ? 30 : 0),
      salary: (a, b) => b.salaryLkr - a.salaryLkr,
      recent: (a, b) => b.posted.localeCompare(a.posted),
      suitability: (a, b) => b.match - a.match,
    };
    return [...r].sort(by[sort]);
  }, [allJobs, q, country, occ, minSal, exp, ctype, verifiedOnly, sort]);

  const active = [country, occ, minSal > 0, exp >= 0, ctype, verifiedOnly].filter(Boolean).length;
  const reset = () => {
    setQ("");
    setCountry("");
    setOcc("");
    setMinSal(0);
    setExp(-1);
    setCtype("");
    setVerifiedOnly(false);
  };
  const variants = ["salary", "standard", "standard", "salary", "standard"] as const;

  return (
    <div>
      {/* Greeting */}
      <section className="grid gap-6 lg:grid-cols-[1fr_280px] lg:items-end">
        <div>
          <p className="eyebrow">Ayubowan, {profile.name} · Sat 17 Oct</p>
          <h1 className="mt-3 text-5xl font-extrabold leading-[0.9] md:text-7xl">
            Your next chapter
            <br />
            abroad, <span className="text-primary">with confidence.</span>
          </h1>
          <p className="mt-4 max-w-xl text-base text-muted-foreground">
            Discover opportunities. Verify the people behind them. Make your move with evidence.
          </p>
        </div>
        <Link
          to="/profile"
          className="group rounded-xl border border-border bg-card p-4 shadow-card"
        >
          <div className="flex items-baseline justify-between">
            <span className="eyebrow">Profile</span>
            <span className="font-mono text-sm font-semibold">{pct}%</span>
          </div>
          <div className="mt-2 flex gap-1">
            {Array.from({ length: 8 }).map((_, i) => (
              <span
                key={i}
                className={cn(
                  "h-1.5 flex-1 rounded-sm",
                  i < Math.round(pct / 12.5) ? "bg-primary" : "bg-secondary",
                )}
              />
            ))}
          </div>
          <p className="mt-2 text-xs text-muted-foreground group-hover:text-foreground">
            Add work preferences to sharpen matches <ArrowRight className="inline h-3 w-3" />
          </p>
        </Link>
      </section>

      {/* Search */}
      <section className="mt-8 rounded-xl border border-border bg-card p-2 shadow-card">
        <div className="flex flex-col gap-2 md:flex-row">
          <label className="flex flex-1 items-center gap-2 px-3">
            <Search className="h-5 w-5 text-muted-foreground" aria-hidden />
            <span className="sr-only">Search jobs</span>
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Occupation, destination or keyword — try “chef” or “Japan”"
              className="h-12 w-full bg-transparent text-base outline-none placeholder:text-muted-foreground"
            />
          </label>
          <div className="flex gap-2">
            <button
              onClick={() => setShowFilters(!showFilters)}
              aria-expanded={showFilters}
              className="inline-flex h-12 flex-1 items-center justify-center gap-2 rounded-md border border-border px-4 text-sm font-semibold md:flex-none"
            >
              <SlidersHorizontal className="h-4 w-4" /> Filters{" "}
              {active > 0 && (
                <span className="rounded bg-primary px-1.5 font-mono text-[11px] text-primary-foreground">
                  {active}
                </span>
              )}
            </button>
            <select
              aria-label="Sort"
              value={sort}
              onChange={(e) => setSort(e.target.value as Sort)}
              className={cn(sel, "h-12 flex-1 md:flex-none")}
            >
              <option value="relevance">Relevance</option>
              <option value="salary">Highest salary</option>
              <option value="recent">Most recent</option>
              <option value="suitability">Best suitability</option>
            </select>
          </div>
        </div>
        {showFilters && (
          <div className="grid gap-3 border-t border-border p-3 sm:grid-cols-2 lg:grid-cols-6 rise-in">
            <select
              aria-label="Destination"
              value={country}
              onChange={(e) => setCountry(e.target.value)}
              className={sel}
            >
              <option value="">Any destination</option>
              {countries.map((c) => (
                <option key={c}>{c}</option>
              ))}
            </select>
            <select
              aria-label="Occupation"
              value={occ}
              onChange={(e) => setOcc(e.target.value)}
              className={sel}
            >
              <option value="">Any occupation</option>
              {occupations.map((c) => (
                <option key={c}>{c}</option>
              ))}
            </select>
            <select
              aria-label="Minimum salary"
              value={minSal}
              onChange={(e) => setMinSal(+e.target.value)}
              className={sel}
            >
              <option value={0}>Any salary</option>
              <option value={150000}>≥ LKR 150k</option>
              <option value={200000}>≥ LKR 200k</option>
              <option value={300000}>≥ LKR 300k</option>
            </select>
            <select
              aria-label="Experience"
              value={exp}
              onChange={(e) => setExp(+e.target.value)}
              className={sel}
            >
              <option value={-1}>Any experience</option>
              <option value={0}>No experience</option>
              <option value={1}>Up to 1 yr</option>
              <option value={3}>Up to 3 yrs</option>
            </select>
            <select
              aria-label="Contract type"
              value={ctype}
              onChange={(e) => setCtype(e.target.value)}
              className={sel}
            >
              <option value="">Any contract</option>
              <option>Fixed term</option>
              <option>Renewable</option>
              <option>Seasonal</option>
            </select>
            <label className="flex h-10 items-center gap-2 rounded-md border border-input bg-card px-3 text-sm font-medium">
              <input
                type="checkbox"
                checked={verifiedOnly}
                onChange={(e) => setVerifiedOnly(e.target.checked)}
                className="accent-[var(--primary)]"
              />{" "}
              Licence verified
            </label>
          </div>
        )}
      </section>

      {/* Featured + trust panel */}
      {!q && active === 0 && (
        <section className="mt-10 grid gap-5 lg:grid-cols-[1.6fr_1fr]">
          {featured ? (
            <Link
              to="/jobs/$id"
              params={{ id: featured.id }}
              className="group relative overflow-hidden rounded-2xl bg-ink p-7 text-ink-foreground grid-lines md:p-9"
            >
              <div className="flex items-start justify-between">
                <span className="eyebrow text-sky">Strongest match this week</span>
                <SaveButton id={featured.id} className="border-ink-foreground/20 bg-ink" />
              </div>
              <div className="mt-10 grid gap-6 md:grid-cols-[1fr_auto] md:items-end">
                <div>
                  <p className="font-mono text-xs text-sky">
                    {featured.flag} — {featured.city}, {featured.country}
                  </p>
                  <h2 className="mt-2 text-4xl font-bold leading-[0.95] md:text-5xl">
                    {featured.role}
                  </h2>
                  <p className="mt-4 max-w-md text-sm text-ink-foreground/70">
                    {featured.matchReasons.join(". ")}.
                  </p>
                </div>
                <div className="md:text-right">
                  <p className="font-display text-5xl font-extrabold">
                    {featured.salary.toLocaleString("en-US")}
                  </p>
                  <p className="font-mono text-xs text-ink-foreground/60">
                    {featured.currency} / month · no fee charged
                  </p>
                </div>
              </div>
              <div className="mt-8 flex flex-wrap items-center gap-x-6 gap-y-2 border-t border-ink-foreground/15 pt-4 text-xs">
                <span>
                  Safety: <b className="text-sky">Low risk</b>
                </span>
                <span>
                  Match: <b className="text-sky">{featured.match}%</b>
                </span>
                <span>
                  Licence: <b className="text-sky">Verified (simulated)</b>
                </span>
                <span className="ml-auto inline-flex items-center gap-1 font-semibold">
                  Open{" "}
                  <ArrowRight className="h-3.5 w-3.5 transition-transform group-hover:translate-x-1" />
                </span>
              </div>
            </Link>
          ) : (
            <div className="rounded-2xl border border-border bg-card p-7 shadow-card flex items-center justify-center text-muted-foreground">
              <p>No featured opportunities right now.</p>
            </div>
          )}

          <aside className="rounded-2xl border border-border bg-card p-6 shadow-card">
            <div className="flex items-center justify-between">
              <h2 className="text-xl font-bold">Trust intelligence</h2>
              <SimulatedTag />
            </div>
            <dl className="mt-5 grid grid-cols-3 divide-x divide-border border-y border-border py-4 text-center">
              <div>
                <dd className="font-display text-3xl font-bold">{trustStats.listingsChecked}</dd>
                <dt className="eyebrow mt-1">Listings</dt>
              </div>
              <div>
                <dd className="font-display text-3xl font-bold">{trustStats.agencies}</dd>
                <dt className="eyebrow mt-1">Agencies</dt>
              </div>
              <div>
                <dd className="font-display text-3xl font-bold text-risk">{trustStats.highRisk}</dd>
                <dt className="eyebrow mt-1">High risk</dt>
              </div>
            </dl>
            <ol className="mt-4 space-y-3">
              {trustStats.activity.map((a) => (
                <li key={a.t} className="grid grid-cols-[auto_1fr] gap-3 text-xs">
                  <span className="font-mono text-muted-foreground">{a.t.slice(5, 10)}</span>
                  <span>{a.text}</span>
                </li>
              ))}
            </ol>
            <Link
              to="/investigate"
              className="mt-5 inline-flex items-center gap-1 text-sm font-semibold text-primary"
            >
              Check an offer you received <ArrowRight className="h-3.5 w-3.5" />
            </Link>
          </aside>
        </section>
      )}

      {/* Results */}
      <section className="mt-12">
        <div className="mb-4 flex items-baseline justify-between">
          <h2 className="text-2xl font-bold">
            {q || active ? "Results" : "Recommended for you"}{" "}
            <span className="font-mono text-sm font-normal text-muted-foreground">
              {results.length}
            </span>
          </h2>
          {(q || active > 0) && (
            <button
              onClick={reset}
              className="inline-flex items-center gap-1 text-sm font-semibold text-primary"
            >
              <X className="h-3.5 w-3.5" /> Clear
            </button>
          )}
        </div>
        {results.length === 0 ? (
          <EmptyState
            title="No roads lead here — yet"
            body="No jobs match these filters. Try widening the destination or salary range."
            action={
              <button
                onClick={reset}
                className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground"
              >
                Reset filters
              </button>
            }
          />
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
            {results.map((j, i) => (
              <JobCard
                key={j.id}
                job={j}
                variant={
                  i === 0 && !q && active === 0
                    ? "wide"
                    : (variants[i % variants.length] ?? "standard")
                }
              />
            ))}
          </div>
        )}
      </section>

      {saved.length > 0 && (
        <section className="mt-12">
          <h2 className="mb-3 text-lg font-bold">
            Saved{" "}
            <span className="font-mono text-sm font-normal text-muted-foreground">
              {saved.length}
            </span>
          </h2>
          <ul className="divide-y divide-border rounded-xl border border-border bg-card">
            {saved
              .map((id) => jobs.find((j) => j.id === id) || getJob(id))
              .filter((j): j is Job => Boolean(j))
              .map((j) => (
                <li key={j.id}>
                  <Link
                    to="/jobs/$id"
                    params={{ id: j.id }}
                    className="flex flex-wrap items-center gap-x-6 gap-y-2 px-4 py-3 hover:bg-muted"
                  >
                    <span className="min-w-48 flex-1 font-semibold">{j.role}</span>
                    <CountryTag code={j.flag} city={j.city} country={j.country} />
                    <span className="font-mono text-xs">{formatMoney(j.salary, j.currency)}</span>
                    <SafetyIndicator risk={j.risk} compact />
                    <MatchMeter value={j.match} />
                    <VerifyBadge state={j.verification} />
                  </Link>
                </li>
              ))}
          </ul>
        </section>
      )}
    </div>
  );
}
