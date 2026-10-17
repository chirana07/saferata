import { createFileRoute, Link } from "@tanstack/react-router";
import { useMemo, useState, useEffect, useCallback, useRef } from "react";
import { Search, SlidersHorizontal, ArrowRight, X, RotateCcw, AlertTriangle, Loader2 } from "lucide-react";
import {
  jobs as demoJobs,
  countries as initialCountries,
  occupations as initialOccupations,
  trustStats as fallbackTrustStats,
  getCompany,
  getJob,
  formatMoney,
  backendJobToUiJob,
  registerLiveJobs,
  registerLiveAgencies,
  getAllJobs,
  type Job,
  type Company,
} from "@/lib/data";
import {
  apiListJobs,
  apiListAgencies,
  apiRecentChecks,
  type BackendCheckView,
  type BackendAgencyView,
  type BackendJobView,
} from "@/lib/api";
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
  const [jobs, setJobs] = useState<Job[]>(() => demoJobs ?? []);
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

  // Trust Intelligence Panel States
  const [trustLoading, setTrustLoading] = useState(true);
  const [trustError, setTrustError] = useState<string | null>(null);
  const [backendChecks, setBackendChecks] = useState<BackendCheckView[]>([]);
  const [backendAgencies, setBackendAgencies] = useState<BackendAgencyView[]>([]);
  const [liveJobsCount, setLiveJobsCount] = useState<number | null>(null);
  const isFetchingRef = useRef(false);

  const fetchTrustData = useCallback(async () => {
    if (isFetchingRef.current) return;
    isFetchingRef.current = true;
    setTrustLoading(true);
    setTrustError(null);

    try {
      const [jobsRes, agenciesRes, checksRes] = await Promise.all([
        apiListJobs(),
        apiListAgencies(),
        apiRecentChecks(6),
      ]);

      let hasLive = false;

      if (jobsRes.jobs && jobsRes.jobs.length > 0) {
        hasLive = true;
        const liveConverted = jobsRes.jobs.map(backendJobToUiJob);
        registerLiveJobs(liveConverted);
        setJobs([...liveConverted, ...(demoJobs ?? [])]);
        setLiveJobsCount(jobsRes.jobs.length);
      } else if (jobsRes.jobs) {
        setLiveJobsCount(0);
      }

      if (agenciesRes.agencies && agenciesRes.agencies.length > 0) {
        hasLive = true;
        setBackendAgencies(agenciesRes.agencies);
        const mappedAgencies: Company[] = agenciesRes.agencies.map((a) => ({
          id: `agency-${a.licence_no.replace(/[^a-zA-Z0-9_-]/g, "_")}`,
          name: a.name,
          type: "Recruitment agency" as const,
          location: "Sri Lanka",
          licence: a.licence_no,
          licenceState: "verified" as const,
          lastChecked: a.checked_at ? a.checked_at.slice(0, 10) : new Date().toISOString().slice(0, 10),
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
        registerLiveAgencies(mappedAgencies);
      }

      if (checksRes.checks) {
        if (checksRes.checks.length > 0) hasLive = true;
        setBackendChecks(checksRes.checks);
      }

      setIsLiveBackend(hasLive);

      if (jobsRes.error && agenciesRes.error && checksRes.error) {
        setTrustError(jobsRes.error.message || "Could not reach Jac backend service.");
      }
    } catch (err: unknown) {
      setTrustError("Failed to fetch trust intelligence. Tap retry to reconnect.");
    } finally {
      setTrustLoading(false);
      isFetchingRef.current = false;
    }
  }, []);

  useEffect(() => {
    fetchTrustData();
  }, [fetchTrustData]);

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

          {/* Trust Intelligence Panel */}
          {(() => {
            // Computed counts from real data or graceful fallback
            const hasBackendData = isLiveBackend && !trustError;
            const listingsCount =
              liveJobsCount !== null ? liveJobsCount : hasBackendData ? allJobs.length : fallbackTrustStats.listingsChecked;
            const agenciesCount =
              backendAgencies.length > 0 ? backendAgencies.length : fallbackTrustStats.agencies;
            
            // Explicit High-Risk calculation rule:
            // Jobs with band === 'DANGER' or score >= 60, plus checks with verdict === 'DANGER'
            const highRiskJobs = (liveJobsCount !== null ? allJobs.slice(0, liveJobsCount) : allJobs).filter(
              (j) => j.risk === "critical" || j.risk === "high" || j.findings?.some((f) => f.severity === "critical"),
            ).length;
            const highRiskChecks = backendChecks.filter(
              (c) => c.verdict === "DANGER" || c.score >= 60,
            ).length;
            const highRiskCount = hasBackendData
              ? highRiskJobs + highRiskChecks
              : fallbackTrustStats.highRisk;

            // Generate recent activity from real backend checks/agencies or genuine events
            type ActivityItem = {
              id: string;
              time: string;
              text: string;
              to?: string;
              type: "check" | "agency" | "listing" | "fallback";
              isDanger?: boolean;
            };

            const activities: ActivityItem[] = [];

            if (backendChecks.length > 0) {
              backendChecks.slice(0, 5).forEach((c) => {
                const timeStr = c.created_at ? (c.created_at.length >= 16 ? c.created_at.slice(11, 16) : c.created_at.slice(5, 10)) : "Today";
                const isDanger = c.verdict === "DANGER" || c.score >= 60;
                activities.push({
                  id: `chk-${c.id}`,
                  time: timeStr,
                  text: `${c.job || "Offer"} in ${c.country || "overseas"} checked → ${c.verdict}${c.alerts?.length ? ` · ${c.alerts.length} alert(s)` : ""}`,
                  to: `/investigate?offer=${encodeURIComponent(`${c.job} in ${c.country} (${c.agency})`)}`,
                  type: "check",
                  isDanger,
                });
              });
            } else if (backendAgencies.length > 0) {
              backendAgencies.slice(0, 4).forEach((a) => {
                const timeStr = a.checked_at ? a.checked_at.slice(5, 10) : "Today";
                activities.push({
                  id: `ag-${a.id}`,
                  time: timeStr,
                  text: `${a.name} (Licence #${a.licence_no}) confirmed against SLBFE register`,
                  to: `/companies/agency-${a.licence_no.replace(/[^a-zA-Z0-9_-]/g, "_")}`,
                  type: "agency",
                });
              });
            } else if (!hasBackendData) {
              fallbackTrustStats.activity.forEach((a, idx) => {
                activities.push({
                  id: `demo-${idx}`,
                  time: a.t.slice(5, 10),
                  text: a.text,
                  type: "fallback",
                });
              });
            }

            return (
              <aside className="rounded-2xl border border-border bg-card p-6 shadow-card flex flex-col justify-between">
                <div>
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <h2 className="text-xl font-bold">Trust intelligence</h2>
                      {trustLoading && <Loader2 className="h-4 w-4 animate-spin text-primary" />}
                    </div>
                    {hasBackendData ? (
                      <span className="inline-flex items-center gap-1 rounded bg-safe-soft px-2 py-0.5 font-mono text-[10px] font-semibold text-safe">
                        ● Live SLBFE graph
                      </span>
                    ) : trustError ? (
                      <span className="inline-flex items-center gap-1 rounded bg-risk-soft px-2 py-0.5 font-mono text-[10px] font-semibold text-risk">
                        Backend unavailable
                      </span>
                    ) : (
                      <SimulatedTag />
                    )}
                  </div>

                  {trustError && (
                    <div className="mt-3 flex items-center justify-between rounded-lg border border-risk/30 bg-risk-soft/40 p-2.5 text-xs text-risk">
                      <div className="flex items-center gap-2">
                        <AlertTriangle className="h-4 w-4 shrink-0" />
                        <span>Offline mode: Showing cached verification data</span>
                      </div>
                      <button
                        onClick={() => fetchTrustData()}
                        className="inline-flex items-center gap-1 font-semibold underline hover:no-underline ml-2"
                      >
                        <RotateCcw className="h-3 w-3" /> Retry
                      </button>
                    </div>
                  )}

                  <dl className="mt-5 grid grid-cols-3 divide-x divide-border border-y border-border py-4 text-center">
                    <div>
                      <dd className="font-display text-3xl font-bold">{listingsCount}</dd>
                      <dt className="eyebrow mt-1">Listings</dt>
                    </div>
                    <div>
                      <dd className="font-display text-3xl font-bold">{agenciesCount}</dd>
                      <dt className="eyebrow mt-1">Agencies</dt>
                    </div>
                    <div>
                      <dd className="font-display text-3xl font-bold text-risk">{highRiskCount}</dd>
                      <dt className="eyebrow mt-1">High risk</dt>
                    </div>
                  </dl>

                  {activities.length === 0 ? (
                    <div className="py-6 text-center text-xs text-muted-foreground">
                      <p>No recent verification events recorded in graph.</p>
                      <button
                        onClick={() => fetchTrustData()}
                        className="mt-2 text-primary font-semibold hover:underline inline-flex items-center gap-1"
                      >
                        <RotateCcw className="h-3 w-3" /> Refresh
                      </button>
                    </div>
                  ) : (
                    <ol className="mt-4 space-y-3">
                      {activities.map((a) => (
                        <li key={a.id} className="grid grid-cols-[auto_1fr] gap-3 text-xs group">
                          <span className="font-mono text-muted-foreground">{a.time}</span>
                          {a.to ? (
                            <Link
                              to={a.to}
                              className={`transition-colors hover:text-primary ${a.isDanger ? "font-semibold text-risk" : "text-foreground"}`}
                            >
                              {a.text} <ArrowRight className="inline h-3 w-3 opacity-0 group-hover:opacity-100 transition-opacity" />
                            </Link>
                          ) : (
                            <span className={a.isDanger ? "font-semibold text-risk" : "text-foreground"}>
                              {a.text}
                            </span>
                          )}
                        </li>
                      ))}
                    </ol>
                  )}
                </div>

                <div className="mt-5 pt-3 border-t border-border flex items-center justify-between">
                  <Link
                    to="/investigate"
                    className="inline-flex items-center gap-1 text-sm font-semibold text-primary hover:text-primary-deep"
                  >
                    Check an offer you received <ArrowRight className="h-3.5 w-3.5" />
                  </Link>
                  <button
                    onClick={() => fetchTrustData()}
                    title="Refresh Trust Intelligence"
                    className="text-muted-foreground hover:text-primary p-1 rounded transition-colors"
                  >
                    <RotateCcw className="h-3.5 w-3.5" />
                  </button>
                </div>
              </aside>
            );
          })()}
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
