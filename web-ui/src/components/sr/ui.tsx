import { Link } from "@tanstack/react-router";
import {
  Bookmark,
  BookmarkCheck,
  ShieldAlert,
  ShieldCheck,
  ShieldQuestion,
  Scale,
  ArrowUpRight,
  CircleDot,
} from "lucide-react";
import type { Job, RiskLevel, VerifyState, Finding } from "@/lib/data";
import { getCompany, formatMoney } from "@/lib/data";
import { toggleSaved, toggleCompare, useStore } from "@/lib/store";
import { cn } from "@/lib/utils";
import { useState } from "react";

export function Logo({ className }: { className?: string }) {
  return (
    <span className={cn("inline-flex items-center gap-2", className)}>
      <svg viewBox="0 0 28 28" className="h-7 w-7" aria-hidden>
        <rect width="28" height="28" rx="7" className="fill-primary" />
        <path
          d="M5 19 Q14 6 23 19"
          className="fill-none stroke-primary-foreground"
          strokeWidth="2.4"
          strokeLinecap="round"
        />
        <circle cx="23" cy="19" r="2.4" className="fill-sky" />
        <path d="M5 22.5 H23" className="stroke-primary-foreground/50" strokeWidth="1.2" />
      </svg>
      <span className="font-display text-lg font-bold tracking-tight">
        Safe<span className="text-primary">Rata</span>
      </span>
    </span>
  );
}

const verifyMeta: Record<VerifyState, { label: string; cls: string }> = {
  verified: { label: "Verified", cls: "bg-safe-soft text-safe" },
  pending: { label: "Pending", cls: "bg-secondary text-primary-deep" },
  expired: { label: "Expired", cls: "bg-caution-soft text-foreground" },
  rejected: { label: "Rejected", cls: "bg-risk-soft text-risk" },
  unverified: { label: "Unverified", cls: "bg-muted text-muted-foreground" },
};

export function VerifyBadge({ state, prefix }: { state: VerifyState; prefix?: string }) {
  const m = verifyMeta[state];
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 text-[11px] font-semibold",
        m.cls,
      )}
    >
      <CircleDot className="h-3 w-3" aria-hidden />
      {prefix ? `${prefix}: ` : ""}
      {m.label}
    </span>
  );
}

const riskMeta: Record<
  RiskLevel,
  { label: string; cls: string; bar: string; Icon: typeof ShieldCheck; n: number }
> = {
  low: { label: "Low risk", cls: "text-safe", bar: "bg-safe", Icon: ShieldCheck, n: 1 },
  moderate: {
    label: "Some concerns",
    cls: "text-foreground",
    bar: "bg-caution",
    Icon: ShieldQuestion,
    n: 2,
  },
  high: { label: "High risk", cls: "text-risk", bar: "bg-risk", Icon: ShieldAlert, n: 3 },
  critical: { label: "Critical risk", cls: "text-risk", bar: "bg-risk", Icon: ShieldAlert, n: 4 },
};

export function SafetyIndicator({ risk, compact }: { risk: RiskLevel; compact?: boolean }) {
  const m = riskMeta[risk];
  return (
    <div className="flex items-center gap-2" aria-label={`Safety assessment: ${m.label}`}>
      <m.Icon className={cn("h-4 w-4", m.cls)} aria-hidden />
      {!compact && <span className={cn("text-xs font-semibold", m.cls)}>{m.label}</span>}
      <span className="flex gap-0.5" aria-hidden>
        {[1, 2, 3, 4].map((i) => (
          <span key={i} className={cn("h-1.5 w-3 rounded-sm", i <= m.n ? m.bar : "bg-border")} />
        ))}
      </span>
    </div>
  );
}

export function MatchMeter({ value }: { value: number }) {
  return (
    <div className="flex items-center gap-2" aria-label={`Personal match ${value} percent`}>
      <span className="font-mono text-xs font-semibold text-primary-deep">{value}%</span>
      <span className="h-1 w-14 overflow-hidden rounded-sm bg-secondary">
        <span className="block h-full bg-primary" style={{ width: `${value}%` }} />
      </span>
      <span className="text-xs text-muted-foreground">match</span>
    </div>
  );
}

export function CountryTag({
  code,
  city,
  country,
}: {
  code: string;
  city: string;
  country: string;
}) {
  return (
    <span className="inline-flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
      <span className="rounded-sm border border-border bg-card px-1 font-mono text-[10px] font-bold text-foreground">
        {code}
      </span>
      {city}, {country}
    </span>
  );
}

export function SaveButton({ id, className }: { id: string; className?: string }) {
  const saved = useStore((s) => s.saved.includes(id));
  return (
    <button
      onClick={(e) => {
        e.preventDefault();
        e.stopPropagation();
        toggleSaved(id);
      }}
      aria-pressed={saved}
      aria-label={saved ? "Remove from saved" : "Save job"}
      className={cn(
        "grid h-9 w-9 place-items-center rounded-md border transition-colors",
        saved
          ? "border-primary bg-primary text-primary-foreground"
          : "border-border bg-card text-muted-foreground hover:border-primary hover:text-primary",
        className,
      )}
    >
      {saved ? <BookmarkCheck className="h-4 w-4" /> : <Bookmark className="h-4 w-4" />}
    </button>
  );
}

export function CompareToggle({ id }: { id: string }) {
  const on = useStore((s) => s.compare.includes(id));
  const full = useStore((s) => s.compare.length >= 3);
  return (
    <button
      onClick={(e) => {
        e.preventDefault();
        e.stopPropagation();
        toggleCompare(id);
      }}
      aria-pressed={on}
      disabled={!on && full}
      title={!on && full ? "You can compare up to 3 jobs" : undefined}
      className={cn(
        "inline-flex h-9 items-center gap-1.5 rounded-md border px-2.5 text-xs font-semibold transition-colors disabled:opacity-40",
        on
          ? "border-primary-deep bg-secondary text-primary-deep"
          : "border-border bg-card text-muted-foreground hover:text-foreground",
      )}
    >
      <Scale className="h-3.5 w-3.5" /> {on ? "Comparing" : "Compare"}
    </button>
  );
}

export function JobCard({
  job,
  variant = "standard",
}: {
  job: Job;
  variant?: "standard" | "salary" | "wide";
}) {
  const agency = getCompany(job.agencyId)!;
  const employer = getCompany(job.employerId)!;
  return (
    <Link
      to="/jobs/$id"
      params={{ id: job.id }}
      className={cn(
        "group relative flex flex-col rounded-xl border border-border bg-card p-5 shadow-card transition-all hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-lift rise-in",
        variant === "wide" && "sm:col-span-2",
      )}
    >
      <div className="flex items-start justify-between gap-3">
        <CountryTag code={job.flag} city={job.city} country={job.country} />
        <div className="flex gap-1.5">
          <SaveButton id={job.id} />
        </div>
      </div>

      {variant === "salary" ? (
        <>
          <p className="mt-5 font-display text-3xl font-bold tracking-tight">
            <span className="mr-1 text-base font-semibold text-muted-foreground">
              {job.currency}
            </span>
            {job.salary.toLocaleString("en-US")}
          </p>
          <p className="text-xs text-muted-foreground">
            per month · ≈ LKR {job.salaryLkr.toLocaleString("en-US")}
          </p>
          <h3 className="mt-3 text-base font-semibold leading-snug tracking-tight">{job.role}</h3>
        </>
      ) : (
        <>
          <h3
            className={cn(
              "mt-4 font-semibold leading-snug tracking-tight",
              variant === "wide" ? "text-2xl" : "text-lg",
            )}
          >
            {job.role}
          </h3>
          <p className="mt-1 text-sm">
            <span className="font-semibold">{formatMoney(job.salary, job.currency)}</span>
            <span className="text-muted-foreground">
              {" "}
              / month · ≈ LKR {job.salaryLkr.toLocaleString("en-US")}
            </span>
          </p>
        </>
      )}

      <dl className="mt-4 grid grid-cols-2 gap-x-4 gap-y-2 border-t border-border pt-3 text-xs">
        <div>
          <dt className="eyebrow">Employer</dt>
          <dd className="mt-0.5 truncate font-medium">{employer.name}</dd>
        </div>
        <div>
          <dt className="eyebrow">Agency</dt>
          <dd className="mt-0.5 truncate font-medium">{agency.name}</dd>
        </div>
        <div className="col-span-2">
          <dt className="eyebrow">Visa</dt>
          <dd className={cn("mt-0.5 font-medium", !job.visaOk && "text-risk")}>{job.visa}</dd>
        </div>
      </dl>

      {variant === "wide" && (
        <p className="mt-3 text-sm text-muted-foreground">
          Why it fits: {job.matchReasons.join(" · ")}
        </p>
      )}

      <div className="mt-auto flex flex-wrap items-center justify-between gap-2 pt-4">
        <SafetyIndicator risk={job.risk} />
        <MatchMeter value={job.match} />
      </div>
      <div className="mt-3 flex items-center justify-between">
        <VerifyBadge state={agency.licenceState} prefix="Licence" />
        {job.promoted && <span className="eyebrow">Promoted · does not affect safety</span>}
      </div>
    </Link>
  );
}

const kindMeta: Record<Finding["kind"], { label: string; cls: string }> = {
  confirmed: { label: "Confirmed in text", cls: "bg-ink text-ink-foreground" },
  suspected: { label: "Suspected", cls: "bg-caution-soft text-foreground" },
  allegation: { label: "Unresolved allegation", cls: "bg-secondary text-primary-deep" },
  unavailable: { label: "Data unavailable", cls: "bg-muted text-muted-foreground" },
};

export function FindingItem({ f, defaultOpen }: { f: Finding; defaultOpen?: boolean }) {
  const [open, setOpen] = useState(!!defaultOpen);
  const sev = riskMeta[f.severity];
  return (
    <li className="border-b border-border last:border-0">
      <button
        onClick={() => setOpen(!open)}
        aria-expanded={open}
        className="flex w-full items-start gap-3 py-3.5 text-left"
      >
        <span className={cn("mt-1.5 h-2 w-2 shrink-0 rounded-sm", sev.bar)} aria-hidden />
        <span className="flex-1">
          <span className="block text-sm font-semibold">{f.title}</span>
          <span className="mt-1 flex flex-wrap gap-1.5">
            <span
              className={cn(
                "rounded px-1.5 py-0.5 text-[10px] font-semibold",
                kindMeta[f.kind].cls,
              )}
            >
              {kindMeta[f.kind].label}
            </span>
            <span className="rounded border border-border px-1.5 py-0.5 text-[10px] text-muted-foreground">
              {f.source}
            </span>
          </span>
        </span>
        <ArrowUpRight
          className={cn("h-4 w-4 text-muted-foreground transition-transform", open && "rotate-90")}
        />
      </button>
      {open && (
        <div className="pb-4 pl-5 rise-in">
          {f.excerpt && (
            <blockquote className="mb-2 border-l-2 border-risk bg-risk-soft/60 px-3 py-2 font-mono text-xs leading-relaxed">
              “{f.excerpt}”
            </blockquote>
          )}
          <p className="text-sm text-muted-foreground">
            <span className="font-semibold text-foreground">Why it matters: </span>
            {f.why}
          </p>
        </div>
      )}
    </li>
  );
}

export function SimulatedTag({ children = "Simulated demo data" }: { children?: React.ReactNode }) {
  return (
    <span className="inline-flex items-center gap-1 rounded border border-dashed border-primary/40 px-1.5 py-0.5 font-mono text-[10px] uppercase tracking-wider text-primary-deep">
      {children}
    </span>
  );
}

export function EmptyState({
  title,
  body,
  action,
}: {
  title: string;
  body: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="rounded-xl border border-dashed border-border bg-card/60 px-6 py-12 text-center">
      <svg viewBox="0 0 120 40" className="mx-auto h-10 w-32" aria-hidden>
        <path
          d="M4 34 Q60 -6 116 34"
          className="fill-none stroke-sky"
          strokeWidth="2"
          strokeDasharray="4 5"
        />
        <circle cx="116" cy="34" r="3" className="fill-primary" />
      </svg>
      <h3 className="mt-4 text-lg font-semibold">{title}</h3>
      <p className="mx-auto mt-1 max-w-sm text-sm text-muted-foreground">{body}</p>
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}

export function PageHeader({
  eyebrow,
  title,
  children,
}: {
  eyebrow: string;
  title: React.ReactNode;
  children?: React.ReactNode;
}) {
  return (
    <header className="mb-8 flex flex-wrap items-end justify-between gap-4 border-b border-border pb-6">
      <div>
        <p className="eyebrow">{eyebrow}</p>
        <h1 className="mt-2 text-4xl font-bold leading-[0.95] md:text-5xl">{title}</h1>
      </div>
      {children}
    </header>
  );
}
