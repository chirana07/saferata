"""Discover + job detail, ported from the layout-coder design (same Tailwind classes) and driven by the real backend."""

import from "lucide-react" { Search, SlidersHorizontal, ArrowRight, ArrowLeft, X, Info, MessageSquare, Bookmark, Scale }
import from jobboard { ListJobs, AddReview, MatchJobs, RespondToReview, RequestCorrection, JobView, JobMatch, PostResult, ReviewView, FindingView }
import from agents { RecentChecks, CheckView, Step }
import from .Profile { prof }
import from .ui { risk_of, SafetyIndicator, MatchMeter, VerifyBadge, CountryTag, FindingItem, LiveTag, EmptyState }

glob SEL = "h-10 rounded-md border border-input bg-card px-3 text-sm font-medium focus:border-primary";

def get_saved -> list[str] {
    try {
        raw: str = localStorage.getItem("saferata.saved") or "";
        return [x.strip() for x in raw.split(",") if x.strip()] if raw else [];
    } except Exception {
        return [];
    }
}

def put_saved(ids: list[str]) {
    try {
        localStorage.setItem("saferata.saved", ",".join(ids));
    } except Exception {}
}

def get_compare -> list[str] {
    try {
        raw: str = localStorage.getItem("saferata.compare") or "";
        return [x.strip() for x in raw.split(",") if x.strip()] if raw else [];
    } except Exception {
        return [];
    }
}

def put_compare(ids: list[str]) {
    try {
        localStorage.setItem("saferata.compare", ",".join(ids));
    } except Exception {}
}

def match_pct(matches: list[JobMatch], job_id: str) -> int {
    hits = [m.match for m in matches if m.job_id == job_id];
    return hits[0] if hits else -1;
}

def match_reasons(matches: list[JobMatch], job_id: str) -> list[str] {
    hits = [m.reasons for m in matches if m.job_id == job_id];
    return hits[0] if hits else [];
}

def match_cautions(matches: list[JobMatch], job_id: str) -> list[str] {
    hits = [m.cautions for m in matches if m.job_id == job_id];
    return hits[0] if hits else [];
}

def lkr(v: float) -> str {
    return f"LKR {v:,.0f}";
}

def finding_kind(source: str) -> str {
    if "Agent" in source {
        return "suspected";
    }
    if "community" in source {
        return "allegation";
    }
    return "confirmed";
}

def finding_risk(points: int) -> str {
    return "critical" if points >= 30 else ("high" if points >= 20 else "moderate");
}

def profile_pct -> int {
    keys = ["occupation", "skills", "experience", "destinations", "min_salary", "name"];
    return int(100 * len([k for k in keys if prof(k, "") and prof(k, "") != "0"]) / len(keys));
}

def:pub Section(category: str, title: str, children: any = None) -> JsxElement {
    return <section className="grid gap-4 border-t border-border py-8 md:grid-cols-[200px_1fr]">
        <div>
            <span className="eyebrow text-[10px] text-primary-deep">{category}</span>
            <h2 className="mt-1 text-xl font-bold tracking-tight">{title}</h2>
        </div>
        <div>{children}</div>
    </section>;
}

def:pub JobCard(job: JobView, matchv: int, reasons: list[str], variant: str, onOpen: Callable[[str], None]) -> JsxElement {
    risk = risk_of(job.band, job.score);
    def open_it(e: MouseEvent) {
        onOpen(job.id);
    }
    return <button onClick={open_it} className={"group relative flex flex-col rounded-xl border border-border bg-card p-5 text-left shadow-card transition-all hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-lift rise-in " + ("sm:col-span-2" if variant == "wide" else "")}>
        <div className="flex items-start justify-between gap-3">
            <CountryTag country={job.country}/>
            {if len(job.warnings) > 0 {
                <span className="rounded-md border border-primary/20 bg-secondary px-2 py-0.5 text-[10px] font-semibold text-primary-deep">Impersonators reported</span>
            }}
        </div>
        {if variant == "salary" {
            <div>
                <p className="mt-4 font-display text-3xl font-extrabold tracking-tight text-foreground">{job.salary}</p>
                <p className="text-xs text-muted-foreground">{("per month · ≈ " + lkr(job.salary_lkr)) if job.salary_lkr > 0 else "per month"}</p>
                <h3 className="mt-2 text-base font-semibold leading-snug tracking-tight text-foreground group-hover:text-primary transition-colors">{job.title}</h3>
            </div>
        } else {
            <div>
                <h3 className={"mt-4 font-semibold leading-snug tracking-tight text-foreground group-hover:text-primary transition-colors " + ("text-2xl" if variant == "wide" else "text-lg")}>{job.title}</h3>
                <p className="mt-1 text-sm"><span className="font-semibold text-foreground">{job.salary}</span><span className="text-muted-foreground">{(" / month · ≈ " + lkr(job.salary_lkr)) if job.salary_lkr > 0 else " / month"}</span></p>
            </div>
        }}
        <dl className="mt-4 grid grid-cols-2 gap-x-4 gap-y-2 border-t border-border pt-3 text-xs">
            <div><dt className="eyebrow">Agency</dt><dd className="mt-0.5 truncate font-medium text-foreground">{job.agency_name}</dd></div>
            <div><dt className="eyebrow">Contract</dt><dd className="mt-0.5 truncate font-medium text-foreground">{(job.contract_type or "—") + (f" · {job.contract_months} mo" if job.contract_months else "")}</dd></div>
            <div className="col-span-2"><dt className="eyebrow">Take-home (est.)</dt><dd className="mt-0.5 font-semibold text-primary-deep">{lkr(job.take_home_lkr) if job.take_home_lkr > 0 else "Not enough data"}</dd></div>
        </dl>
        {if variant == "wide" and len(reasons) > 0 {
            <p className="mt-3 text-sm text-muted-foreground">{"Why it fits: " + " · ".join(reasons)}</p>
        }}
        <div className="mt-auto flex flex-wrap items-center justify-between gap-2 pt-4">
            <SafetyIndicator risk={risk}/>
            {if matchv >= 0 {
                <MatchMeter value={matchv}/>
            }}
        </div>
        <div className="mt-3 flex items-center justify-between">
            <VerifyBadge state="verified" prefix="Licence"/>
            {if job.credible_fraud_reports > 0 {
                <span className="eyebrow text-risk">{f"{job.credible_fraud_reports} fraud report(s)"}</span>
            }}
        </div>
    </button>;
}

def:pub Discover(onCheck: Callable[[], None], onProfile: Callable[[], None]) -> JsxElement {
    has jobs: list[JobView] = [],
        checks: list[CheckView] = [],
        matches: list[JobMatch] = [],
        loading: bool = False,
        q: str = "",
        country: str = "",
        occ: str = "",
        min_sal: str = "0",
        exp: str = "-1",
        ctype: str = "",
        sort: str = "relevance",
        show_filters: bool = False,
        open_id: str = "",
        enquire: bool = False,
        review_author: str = "",
        review_kind: str = "fraud",
        review_text: str = "",
        review_evidence: str = "",
        reviewing: bool = False,
        respond_id: str = "",
        respond_text: str = "",
        correction: str = "",
        message: str = "",
        last_steps: list[Step] = [],
        saved_ids: list[str] = [],
        compare_ids: list[str] = [],
        show_compare: bool = False,
        saved_only: bool = False;

    def toggle_save(jid: str) {
        if jid in saved_ids {
            saved_ids = [x for x in saved_ids if x != jid];
        } else {
            saved_ids = saved_ids + [jid];
        }
        put_saved(saved_ids);
    }

    def toggle_compare(jid: str) {
        if jid in compare_ids {
            compare_ids = [x for x in compare_ids if x != jid];
        } else {
            if len(compare_ids) < 3 {
                compare_ids = compare_ids + [jid];
            }
        }
        put_compare(compare_ids);
    }

    async def load -> None {
        loading = True;
        result = root spawn ListJobs();
        jobs = result.reports;
        rc = root spawn RecentChecks();
        checks = rc.reports;
        if prof("saved", "") == "yes" {
            mres = root spawn MatchJobs(occupation=prof("occupation", ""), skills=[x.strip() for x in prof("skills", "").split(",") if x.strip()],
                destinations=[x.strip() for x in prof("destinations", "").split(",") if x.strip()], min_salary_lkr=float(prof("min_salary", "0") or "0"),
                experience_years=int(prof("experience", "0") or "0"), needs_accommodation=prof("accommodation", "yes") == "yes");
            matches = mres.reports;
        }
        loading = False;
    }

    async def submit_review -> None {
        if len(review_text.strip()) < 10 {
            message = "Please provide more details in your report (at least 10 characters).";
            return;
        }
        reviewing = True;
        result = root spawn AddReview(job_id=open_id, author=review_author, kind=review_kind, text=review_text, evidence=review_evidence);
        if result.reports {
            r: PostResult = result.reports[0];
            message = r.message;
            last_steps = r.steps;
        }
        review_text = "";
        review_evidence = "";
        reviewing = False;
        await load();
    }

    async def respond -> None {
        if not respond_text.strip() {
            return;
        }
        result = root spawn RespondToReview(review_id=respond_id, response=respond_text);
        if result.reports {
            r: PostResult = result.reports[0];
            message = r.message;
        }
        respond_id = "";
        respond_text = "";
        await load();
    }

    async def request_correction -> None {
        if len(correction.strip()) < 5 {
            message = "Please describe what is wrong in the listing (at least 5 characters).";
            return;
        }
        result = root spawn RequestCorrection(job_id=open_id, details=correction);
        if result.reports {
            r: PostResult = result.reports[0];
            message = r.message;
        }
        correction = "";
        await load();
    }

    def open_job(jid_: str) {
        open_id = jid_;
        message = "";
        last_steps = [];
        enquire = False;
    }

    def reset {
        q = "";
        country = "";
        occ = "";
        min_sal = "0";
        exp = "-1";
        ctype = "";
    }

    can with entry {
        saved_ids = get_saved();
        compare_ids = get_compare();
        load();
    }

    term = q.strip().lower();
    minv = float(min_sal or "0");
    expv = int(exp or "-1");
    results = [j for j in jobs if (not term or term in (j.title + " " + j.country + " " + j.occupation + " " + j.description).lower())
        and (not country or j.country == country) and (not occ or j.occupation == occ) and j.salary_lkr >= minv
        and (expv < 0 or j.experience_years <= expv) and (not ctype or j.contract_type == ctype)
        and (not saved_only or j.id in saved_ids)];
    if sort == "salary" {
        results = sorted(results, key=lambda (j: JobView) { -j.salary_lkr; });
    } elif sort == "recent" {
        results = sorted(results, key=lambda (j: JobView) { j.posted_at; }, reverse=True);
    } elif sort == "suitability" or sort == "relevance" {
        results = sorted(results, key=lambda (j: JobView) { -(match_pct(matches, j.id)) + (30 if j.band == "DANGER" else 0); });
    }
    active = len([x for x in [country, occ, min_sal != "0", exp != "-1", ctype] if x]);
    countries = sorted(list(set([j.country for j in jobs if j.country])));
    occupations = sorted(list(set([j.occupation for j in jobs if j.occupation])));
    safe_jobs = [j for j in jobs if j.band == "LOOKS SAFE"];
    featured: list[JobView] = sorted(safe_jobs, key=lambda (j: JobView) { -match_pct(matches, j.id); })[:1];
    pct = profile_pct();
    variants = ["salary", "standard", "standard", "salary", "standard"];
    opened = [j for j in jobs if j.id == open_id];
    comp_jobs = [j for j in jobs if j.id in compare_ids];

    if opened {
        jb = opened[0];
        risk = risk_of(jb.band, jb.score);
        mv = match_pct(matches, jb.id);
        deducted = jb.salary_lkr - jb.take_home_lkr;
        return <article>
            <button onClick={lambda -> None { open_id = ""; }} className="inline-flex items-center gap-1 text-sm font-semibold text-muted-foreground hover:text-foreground"><ArrowLeft className="h-4 w-4"/> Discover</button>
            <header className="mt-6 grid gap-8 lg:grid-cols-[1fr_320px]">
                <div>
                    <CountryTag country={jb.country}/>
                    <h1 className="mt-3 text-4xl font-extrabold leading-[0.95] md:text-6xl">{jb.title}</h1>
                    <p className="mt-4 text-sm text-muted-foreground"><span className="font-semibold text-foreground">{jb.agency_name}</span>{f" · SLBFE licence {jb.licence_no} · posted {jb.posted_at}"}</p>
                    <div className="mt-5 flex flex-wrap items-center gap-2">
                        <button onClick={lambda -> None { enquire = not enquire; }} className="inline-flex h-9 items-center gap-1.5 rounded-md bg-primary px-3 text-sm font-semibold text-primary-foreground hover:bg-primary-deep"><MessageSquare className="h-4 w-4"/> Enquire</button>
                        <button onClick={lambda -> None { toggle_save(jb.id); }} className={"inline-flex h-9 items-center gap-1.5 rounded-md border px-3 text-sm font-semibold transition-colors " + ("border-primary bg-primary/10 text-primary font-bold" if jb.id in saved_ids else "border-border bg-card text-muted-foreground hover:text-foreground")}>
                            <Bookmark className={"h-4 w-4 " + ("fill-primary" if jb.id in saved_ids else "")}/> {if jb.id in saved_ids { "Saved"; } else { "Save"; }}
                        </button>
                        <button onClick={lambda -> None { toggle_compare(jb.id); }} className={"inline-flex h-9 items-center gap-1.5 rounded-md border px-3 text-sm font-semibold transition-colors " + ("border-primary bg-primary/10 text-primary font-bold" if jb.id in compare_ids else "border-border bg-card text-muted-foreground hover:text-foreground")}>
                            <Scale className="h-4 w-4"/> {if jb.id in compare_ids { "Comparing"; } else { "Compare"; }}
                        </button>
                    </div>
                    {if enquire {
                        <div className="mt-4 rounded-xl border border-border bg-card p-4 shadow-card rise-in">
                            <p className="text-sm font-semibold">Ask the agency before paying anything</p>
                            <ol className="mt-2 list-decimal space-y-1 pl-5 text-sm">
                                <li>Can I see the full contract before paying anything?</li>
                                <li>{"What is the employer's registration number?"}</li>
                                <li>Which fees will I pay, to whom, and will I get a receipt?</li>
                            </ol>
                        </div>
                    }}
                </div>
                <div className="rounded-xl border border-border bg-card p-5 shadow-card">
                    <p className="eyebrow">Monthly salary</p>
                    <p className="mt-1 font-display text-4xl font-extrabold">{jb.salary}</p>
                    <p className="text-xs text-muted-foreground">{("≈ " + lkr(jb.salary_lkr) + " at approximate fixed rate") if jb.salary_lkr > 0 else "Not convertible"}</p>
                    <div className="mt-4 space-y-3 border-t border-border pt-4">
                        <div><p className="eyebrow mb-1">Safety assessment</p><SafetyIndicator risk={risk}/></div>
                        <div><p className="eyebrow mb-1">Your match</p>{if mv >= 0 { <MatchMeter value={mv}/> } else { <button onClick={lambda -> None { onProfile(); }} className="text-xs font-semibold text-primary">Add your profile</button> }}</div>
                        <div><p className="eyebrow mb-1">Status</p><VerifyBadge state="verified" prefix="Licence (live register)"/></div>
                    </div>
                </div>
            </header>
            <p className="mt-8 flex items-start gap-2 rounded-lg border border-caution/50 bg-caution-soft px-4 py-3 text-sm"><Info className="mt-0.5 h-4 w-4 shrink-0"/> Verification is not a guarantee of safety. Always confirm your contract with the Sri Lanka Bureau of Foreign Employment before paying or travelling.</p>
            {[<p key={i} className="mt-3 rounded-lg border border-primary/30 bg-secondary px-4 py-3 text-sm font-semibold text-primary-deep">{"Impersonation alert: " + w}</p> for (i, w) in enumerate(jb.warnings)]}
            <div className="mt-6">
                <Section category="Forensic Review" title="Safety findings">
                    <div className="mb-2 flex items-center gap-2"><LiveTag label="Real agent analysis"/><span className="text-xs text-muted-foreground">{f"{jb.score}/100 · separate from match score. Promotion never changes it."}</span></div>
                    {if len(jb.findings) == 0 {
                        <p className="rounded-xl border border-border bg-card px-4 py-4 text-sm text-muted-foreground">No supported findings. That is not proof the job is safe.</p>
                    } else {
                        <ul className="rounded-xl border border-border bg-card px-4">
                            {[<FindingItem key={i} title={f.title} risk={finding_risk(f.points)} kind={finding_kind(f.source)} source={f.source} excerpt={f.evidence} why={f.explanation} open_default={i == 0}/> for (i, f) in enumerate(jb.findings)]}
                        </ul>
                    }}
                    <p className="mt-2 text-sm text-muted-foreground">{jb.summary}</p>
                    {[<p key={k} className="mt-2 text-xs font-semibold text-primary-deep">{"Appeal " + ap}</p> for (k, ap) in enumerate(jb.appeals)]}
                    <details className="mt-3 text-sm"><summary className="cursor-pointer font-semibold">Full job description</summary><p className="mt-2 whitespace-pre-wrap text-muted-foreground">{jb.description}</p></details>
                </Section>
                <Section category="Compensation" title="Pay & deductions">
                    <table className="w-full text-sm"><tbody className="divide-y divide-border">
                        <tr><td className="py-2">Basic salary</td><td className="py-2 text-right font-mono">{jb.salary}</td></tr>
                        <tr><td className="py-2 text-muted-foreground">{"− " + (jb.deductions or "Deductions")}</td><td className="py-2 text-right font-mono">{lkr(deducted) if deducted > 0 else "None disclosed"}</td></tr>
                        <tr className="font-semibold"><td className="py-2">Estimated take-home</td><td className="py-2 text-right font-mono">{lkr(jb.take_home_lkr) if jb.take_home_lkr > 0 else "Not enough data"}</td></tr>
                        <tr><td className="py-2">Recruitment fee to you</td><td className={"py-2 text-right font-mono " + ("font-semibold text-risk" if jb.worker_fee_lkr > 150000 else "")}>{lkr(jb.worker_fee_lkr) if jb.worker_fee_lkr > 0 else "None stated"}</td></tr>
                        <tr><td className="py-2">Accommodation</td><td className="py-2 text-right">{jb.accommodation or "Not stated"}</td></tr>
                    </tbody></table>
                    {[<p key={k} className="mt-2 text-xs text-muted-foreground">{"Correction requested " + c}</p> for (k, c) in enumerate(jb.corrections)]}
                </Section>
                <Section category="Legal Terms" title="Visa & contract">
                    <dl className="grid gap-4 sm:grid-cols-3">
                        <div><dt className="eyebrow">Occupation</dt><dd className="mt-1 font-semibold">{jb.occupation or "—"}</dd></div>
                        <div><dt className="eyebrow">Contract</dt><dd className="mt-1 font-semibold">{(jb.contract_type or "—") + (f" · {jb.contract_months} months" if jb.contract_months else "")}</dd></div>
                        <div><dt className="eyebrow">Experience</dt><dd className="mt-1 font-semibold">{f"{jb.experience_years}+ years" if jb.experience_years else "None required"}</dd></div>
                    </dl>
                </Section>
                <Section category="Candidate Fit" title="Why it matches">
                    {if mv >= 0 {
                        <div>
                            <ul className="space-y-2">{[<li key={k} className="flex gap-2 text-sm"><span className="mt-2 h-1 w-3 bg-primary"></span>{r}</li> for (k, r) in enumerate(match_reasons(matches, jb.id))]}</ul>
                            <ul className="mt-2 space-y-2">{[<li key={k} className="flex gap-2 text-sm text-risk"><span className="mt-2 h-1 w-3 bg-risk"></span>{c}</li> for (k, c) in enumerate(match_cautions(matches, jb.id))]}</ul>
                        </div>
                    } else {
                        <button onClick={lambda -> None { onProfile(); }} className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground">Add your profile to see why it matches</button>
                    }}
                    <p className="mt-3 text-xs text-muted-foreground">Based on your profile. A high match does not mean a job is safe.</p>
                </Section>
                <Section category="Agency Identity" title="Who's behind it">
                    <div className="rounded-xl border border-border bg-card p-4">
                        <p className="eyebrow">Recruitment agency</p>
                        <p className="mt-1 font-semibold">{jb.agency_name}</p>
                        <p className="mt-1 text-xs text-muted-foreground">{f"SLBFE licence {jb.licence_no}, checked on the live register when this job was posted. Contact given: {jb.contact_phone}"}</p>
                        <div className="mt-3 flex items-center justify-between"><VerifyBadge state="verified"/><span className="text-xs text-muted-foreground">{f"{len(jb.reviews)} moderated reports"}</span></div>
                    </div>
                </Section>
                <Section category="Community Audit" title="Worker reports">
                    <ul className="divide-y divide-border rounded-xl border border-border bg-card px-4">
                        {if len(jb.reviews) == 0 {
                            <li className="py-4 text-sm text-muted-foreground">No reports yet.</li>
                        }}
                        {[
                            <li key={rv.id} className="py-4 text-sm">
                                <div className="flex flex-wrap items-center gap-1.5">
                                    <span className="font-semibold">{rv.author}</span>
                                    <span className={"rounded px-1.5 py-0.5 text-[10px] font-semibold " + ("bg-risk-soft text-risk" if rv.kind == "fraud" else "bg-safe-soft text-safe")}>{rv.kind}</span>
                                    <span className="rounded border border-border px-1.5 py-0.5 text-[10px] text-muted-foreground">{f"Review Verifier: {rv.status} · {rv.credibility}/100"}</span>
                                    <span className="font-mono text-[11px] text-muted-foreground">{rv.created_at}</span>
                                </div>
                                <p className="mt-1">{rv.text}</p>
                                {if rv.evidence {
                                    <p className="mt-1 font-mono text-xs text-muted-foreground">{"Evidence: " + rv.evidence}</p>
                                }}
                                <p className="mt-1 text-xs text-muted-foreground">{rv.reason}</p>
                                {if rv.agency_response {
                                    <p className="mt-2 rounded-md bg-secondary px-3 py-2 text-xs"><span className="font-semibold text-primary-deep">Agency response: </span>{rv.agency_response}</p>
                                }}
                                {if respond_id == rv.id {
                                    <div className="mt-2 flex gap-2">
                                        <input value={respond_text} onChange={lambda (e: ChangeEvent) { respond_text = e.target.value; }} placeholder="Agency response" className={SEL + " flex-1"}/>
                                        <button onClick={lambda { respond(); }} className="rounded-md bg-primary px-3 text-sm font-semibold text-primary-foreground">Publish</button>
                                    </div>
                                } elif not rv.agency_response {
                                    <button onClick={lambda -> None { respond_id = rv.id; }} className="mt-2 text-xs font-semibold text-primary">Respond as agency</button>
                                }}
                            </li>
                            for rv in jb.reviews
                        ]}
                    </ul>
                    {if message {
                        <div className="mt-4 rounded-xl border border-primary/20 bg-secondary p-4 text-xs shadow-card rise-in">
                            <p className="font-semibold text-primary-deep">{message}</p>
                            {if len(last_steps) > 0 {
                                <ol className="mt-1.5 list-decimal space-y-0.5 pl-4 text-foreground/80">{[<li key={k}><span className="font-semibold">{s.agent}</span>{": " + s.detail}</li> for (k, s) in enumerate(last_steps)]}</ol>
                            }}
                        </div>
                    }}
                    <div className="mt-4 grid gap-4 md:grid-cols-2">
                        <div className="rounded-xl border border-border bg-card p-4 shadow-card">
                            <p className="font-semibold">Report or review this job</p>
                            <div className="mt-3 space-y-2">
                                <input value={review_author} onChange={lambda (e: ChangeEvent) { review_author = e.target.value; }} placeholder="Your name (optional)" className={SEL + " w-full"}/>
                                <select value={review_kind} onChange={lambda (e: ChangeEvent) { review_kind = e.target.value; }} className={SEL + " w-full"}>
                                    <option value="fraud">Report fraud</option><option value="positive">Positive experience</option><option value="other">Other</option>
                                </select>
                                <textarea rows={3} value={review_text} onChange={lambda (e: ChangeEvent) { review_text = e.target.value; }} placeholder="What happened? Amounts, dates, what was promised." className="w-full rounded-md border border-input bg-card px-3 py-2 text-sm"/>
                                <textarea rows={2} value={review_evidence} onChange={lambda (e: ChangeEvent) { review_evidence = e.target.value; }} placeholder="Evidence: receipt, bank slip details, chat excerpt" className="w-full rounded-md border border-input bg-card px-3 py-2 text-sm"/>
                                <p className="text-[11px] text-muted-foreground">{"Don't include your NIC, passport number or phone number."}</p>
                                <button disabled={reviewing} onClick={lambda { submit_review(); }} className="w-full rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground">{"Review Verifier checking..." if reviewing else "Submit for moderation"}</button>
                            </div>
                        </div>
                        <div className="rounded-xl border border-border bg-card p-4 shadow-card">
                            <p className="font-semibold">Request a correction</p>
                            <textarea rows={3} value={correction} onChange={lambda (e: ChangeEvent) { correction = e.target.value; }} placeholder="What is wrong in this listing?" className="mt-3 w-full rounded-md border border-input bg-card px-3 py-2 text-sm"/>
                            <button onClick={lambda { request_correction(); }} className="mt-2 rounded-md border border-border px-4 py-2 text-sm font-semibold">Send for moderation</button>
                        </div>
                    </div>
                </Section>
            </div>
        </article>;
    }

    return <div>
        <section className="grid gap-6 lg:grid-cols-[1fr_280px] lg:items-end">
            <div>
                <p className="eyebrow">{"Ayubowan" + ((", " + prof("name", "")) if prof("name", "") else "") + " · Sat 17 Oct"}</p>
                <h1 className="mt-3 text-5xl font-extrabold leading-[0.9] md:text-7xl">Your next chapter<br/>abroad, <span className="text-primary">with confidence.</span></h1>
                <p className="mt-4 max-w-xl text-base text-muted-foreground">Discover opportunities. Verify the people behind them. Make your move with evidence.</p>
            </div>
            <button onClick={lambda -> None { onProfile(); }} className="group rounded-xl border border-border bg-card p-4 text-left shadow-card">
                <div className="flex items-baseline justify-between"><span className="eyebrow">Profile</span><span className="font-mono text-sm font-semibold">{f"{pct}%"}</span></div>
                <div className="mt-2 flex gap-1">{[<span key={i} className={"h-1.5 flex-1 rounded-sm " + ("bg-primary" if i < round(pct / 12.5) else "bg-secondary")}></span> for i in range(8)]}</div>
                <p className="mt-2 text-xs text-muted-foreground group-hover:text-foreground">Add work preferences to sharpen matches <ArrowRight className="inline h-3 w-3"/></p>
            </button>
        </section>

        <section className="mt-8 rounded-xl border border-border bg-card p-2 shadow-card">
            <div className="flex flex-col gap-2 md:flex-row">
                <label className="flex flex-1 items-center gap-2 px-3">
                    <Search className="h-5 w-5 text-muted-foreground"/>
                    <input value={q} onChange={lambda (e: ChangeEvent) { q = e.target.value; }} placeholder="Occupation, destination or keyword — try “driver” or “Qatar”" className="h-12 w-full bg-transparent text-base outline-none placeholder:text-muted-foreground"/>
                </label>
                <div className="flex gap-2">
                    <button onClick={lambda -> None { saved_only = not saved_only; }} className={"inline-flex h-12 items-center justify-center gap-1.5 rounded-md border px-3 text-sm font-semibold transition-all md:flex-none " + ("border-primary bg-primary text-primary-foreground shadow-sm" if saved_only else "border-border bg-card text-muted-foreground hover:text-foreground")}>
                        <Bookmark className={"h-4 w-4 " + ("fill-current" if saved_only else "")}/> Saved {if len(saved_ids) > 0 { <span className="rounded bg-primary-foreground/20 px-1.5 font-mono text-[11px]">{str(len(saved_ids))}</span> }}
                    </button>
                    <button onClick={lambda -> None { show_filters = not show_filters; }} className="inline-flex h-12 flex-1 items-center justify-center gap-2 rounded-md border border-border px-4 text-sm font-semibold md:flex-none">
                        <SlidersHorizontal className="h-4 w-4"/> Filters {if active > 0 { <span className="rounded bg-primary px-1.5 font-mono text-[11px] text-primary-foreground">{str(active)}</span> }}
                    </button>
                    <select value={sort} onChange={lambda (e: ChangeEvent) { sort = e.target.value; }} className={SEL + " h-12 flex-1 md:flex-none"}>
                        <option value="relevance">Relevance</option><option value="salary">Highest salary</option><option value="recent">Most recent</option><option value="suitability">Best suitability</option>
                    </select>
                </div>
            </div>
            {if show_filters {
                <div className="grid gap-3 border-t border-border p-3 sm:grid-cols-2 lg:grid-cols-5 rise-in">
                    <select value={country} onChange={lambda (e: ChangeEvent) { country = e.target.value; }} className={SEL}><option value="">Any destination</option>{[<option key={c} value={c}>{c}</option> for c in countries]}</select>
                    <select value={occ} onChange={lambda (e: ChangeEvent) { occ = e.target.value; }} className={SEL}><option value="">Any occupation</option>{[<option key={c} value={c}>{c}</option> for c in occupations]}</select>
                    <select value={min_sal} onChange={lambda (e: ChangeEvent) { min_sal = e.target.value; }} className={SEL}><option value="0">Any salary</option><option value="150000">≥ LKR 150k</option><option value="200000">≥ LKR 200k</option><option value="300000">≥ LKR 300k</option></select>
                    <select value={exp} onChange={lambda (e: ChangeEvent) { exp = e.target.value; }} className={SEL}><option value="-1">Any experience</option><option value="0">No experience</option><option value="1">Up to 1 yr</option><option value="3">Up to 3 yrs</option></select>
                    <select value={ctype} onChange={lambda (e: ChangeEvent) { ctype = e.target.value; }} className={SEL}><option value="">Any contract</option><option value="Fixed term">Fixed term</option><option value="Renewable">Renewable</option><option value="Seasonal">Seasonal</option></select>
                </div>
            }}
        </section>

        {if not term and active == 0 {
            <section className="mt-10 grid gap-5 lg:grid-cols-[1.6fr_1fr]">
                {if len(featured) > 0 {
                    <button onClick={lambda -> None { open_job(featured[0].id); }} className="group relative overflow-hidden rounded-2xl bg-ink p-7 text-left text-ink-foreground grid-lines md:p-9">
                        <div className="flex items-start justify-between"><span className="eyebrow text-sky">{"Strongest match this week" if match_pct(matches, featured[0].id) >= 0 else "Verified listing"}</span></div>
                        <div className="mt-10 grid gap-6 md:grid-cols-[1fr_auto] md:items-end">
                            <div>
                                <p className="font-mono text-xs text-sky">{featured[0].country[:2].upper() + " — " + featured[0].country}</p>
                                <h2 className="mt-2 text-4xl font-bold leading-[0.95] md:text-5xl">{featured[0].title}</h2>
                                <p className="mt-4 max-w-md text-sm text-ink-foreground/70">{". ".join(match_reasons(matches, featured[0].id)) or featured[0].description[:140]}</p>
                            </div>
                            <div className="md:text-right">
                                <p className="font-display text-5xl font-extrabold">{featured[0].salary}</p>
                                <p className="font-mono text-xs text-ink-foreground/60">{"per month · " + ("no fee charged" if featured[0].worker_fee_lkr == 0 else lkr(featured[0].worker_fee_lkr) + " fee")}</p>
                            </div>
                        </div>
                        <div className="mt-8 flex flex-wrap items-center gap-x-6 gap-y-2 border-t border-ink-foreground/15 pt-4 text-xs">
                            <span>Safety: <b className="text-sky">Low risk</b></span>
                            {if match_pct(matches, featured[0].id) >= 0 { <span>Match: <b className="text-sky">{f"{match_pct(matches, featured[0].id)}%"}</b></span> }}
                            <span>Licence: <b className="text-sky">Verified (live register)</b></span>
                            <span className="ml-auto inline-flex items-center gap-1 font-semibold">Open <ArrowRight className="h-3.5 w-3.5 transition-transform group-hover:translate-x-1"/></span>
                        </div>
                    </button>
                } else {
                    <EmptyState title="No verified listings yet" body="Licensed agencies can post from the Agency portal."/>
                }}
                <aside className="rounded-2xl border border-border bg-card p-6 shadow-card">
                    <div className="flex items-center justify-between"><h2 className="text-xl font-bold">Trust intelligence</h2><LiveTag/></div>
                    <dl className="mt-5 grid grid-cols-3 divide-x divide-border border-y border-border py-4 text-center">
                        <div><dd className="font-display text-3xl font-bold">{str(len(jobs) + len(checks))}</dd><dt className="eyebrow mt-1">Checked</dt></div>
                        <div><dd className="font-display text-3xl font-bold">{str(len(set([j.licence_no for j in jobs])))}</dd><dt className="eyebrow mt-1">Agencies</dt></div>
                        <div><dd className="font-display text-3xl font-bold text-risk">{str(len([c for c in checks if c.verdict == "DANGER"]) + len([j for j in jobs if j.band == "DANGER"]))}</dd><dt className="eyebrow mt-1">High risk</dt></div>
                    </dl>
                    <ol className="mt-4 space-y-3">
                        {[<li key={c.id} className="grid grid-cols-[auto_1fr] gap-3 text-xs"><span className="font-mono text-muted-foreground">{c.created_at[11:16]}</span><span>{f"{c.job or 'Offer'} in {c.country or '?'} checked → {c.verdict}" + (f" · {len(c.alerts)} alert(s)" if c.alerts else "")}</span></li> for c in checks[:5]]}
                    </ol>
                    <button onClick={lambda -> None { onCheck(); }} className="mt-5 inline-flex items-center gap-1 text-sm font-semibold text-primary">Check an offer you received <ArrowRight className="h-3.5 w-3.5"/></button>
                </aside>
            </section>
        }}

        <section className="mt-12">
            <div className="mb-4 flex items-baseline justify-between">
                <h2 className="text-2xl font-bold">{"Results" if (term or active) else "Recommended for you"} <span className="font-mono text-sm font-normal text-muted-foreground">{str(len(results))}</span></h2>
                {if term or active > 0 { <button onClick={lambda -> None { reset(); }} className="inline-flex items-center gap-1 text-sm font-semibold text-primary"><X className="h-3.5 w-3.5"/> Clear</button> }}
            </div>
            {if len(results) == 0 and not loading {
                <EmptyState title="No roads lead here — yet" body="No jobs match these filters. Try widening the destination or salary range."/>
            } else {
                <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
                    {[<JobCard key={j.id} job={j} matchv={match_pct(matches, j.id)} reasons={match_reasons(matches, j.id)} variant={"wide" if (i == 0 and not term and active == 0) else variants[i % 5]} onOpen={open_job}/> for (i, j) in enumerate(results)]}
                </div>
            }}
        </section>

        {if len(compare_ids) > 0 {
            <aside className="fixed bottom-6 right-6 z-40 flex items-center gap-3 rounded-full border border-primary/40 bg-card/95 px-5 py-3 shadow-lift backdrop-blur rise-in">
                <span className="flex items-center gap-2 text-xs font-semibold">
                    <Scale className="h-4 w-4 text-primary"/>
                    <span>{f"{len(compare_ids)}/3 jobs in compare"}</span>
                </span>
                <button onClick={lambda -> None { show_compare = True; }} className="rounded-full bg-primary px-3.5 py-1 text-xs font-bold text-primary-foreground hover:bg-primary-deep">
                    Compare now
                </button>
                <button onClick={lambda -> None { compare_ids = []; put_compare([]); }} className="text-muted-foreground hover:text-foreground">
                    <X className="h-3.5 w-3.5"/>
                </button>
            </aside>
        }}

        {if show_compare {
            <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm">
                <div className="relative max-h-[90vh] w-full max-w-5xl overflow-y-auto rounded-2xl border border-border bg-card p-6 shadow-2xl rise-in">
                    <div className="flex items-center justify-between border-b border-border pb-4">
                        <div>
                            <span className="eyebrow text-primary">Side-by-side analysis</span>
                            <h2 className="mt-1 text-2xl font-bold">Compare Overseas Listings</h2>
                        </div>
                        <button onClick={lambda -> None { show_compare = False; }} className="rounded-lg p-2 text-muted-foreground hover:bg-secondary hover:text-foreground">
                            <X className="h-5 w-5"/>
                        </button>
                    </div>
                    {if len(comp_jobs) == 0 {
                        <div className="py-12 text-center text-sm text-muted-foreground">
                            No jobs selected for comparison yet. Open any job and click "Compare" to add it.
                        </div>
                    } else {
                        <div className="mt-6 overflow-x-auto">
                            <table className="w-full min-w-[600px] text-sm">
                                <thead>
                                    <tr className="border-b border-border">
                                        <th className="w-44 pb-3 text-left eyebrow">Specification</th>
                                        {[
                                            <th key={cj.id} className="pb-3 text-left align-top">
                                                <div className="flex items-start justify-between gap-2">
                                                    <div>
                                                        <span className="font-bold text-foreground">{cj.title}</span>
                                                        <p className="text-xs text-muted-foreground">{cj.country + " · " + cj.agency_name}</p>
                                                    </div>
                                                    <button onClick={lambda -> None { toggle_compare(cj.id); }} className="text-muted-foreground hover:text-risk">
                                                        <X className="h-3.5 w-3.5"/>
                                                    </button>
                                                </div>
                                            </th>
                                            for cj in comp_jobs
                                        ]}
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-border">
                                    <tr>
                                        <td className="py-3 font-semibold text-muted-foreground">Monthly Salary</td>
                                        {[<td key={cj.id} className="py-3 font-mono font-semibold">{cj.salary} <span className="text-xs font-normal text-muted-foreground">{(f"· ≈ " + lkr(cj.salary_lkr)) if cj.salary_lkr > 0 else ""}</span></td> for cj in comp_jobs]}
                                    </tr>
                                    <tr>
                                        <td className="py-3 font-semibold text-muted-foreground">Est. Net Take-Home</td>
                                        {[<td key={cj.id} className="py-3 font-mono font-semibold text-primary-deep">{lkr(cj.take_home_lkr) if cj.take_home_lkr > 0 else "Not enough data"}</td> for cj in comp_jobs]}
                                    </tr>
                                    <tr>
                                        <td className="py-3 font-semibold text-muted-foreground">Worker Recruitment Fee</td>
                                        {[<td key={cj.id} className={"py-3 font-mono " + ("font-bold text-risk" if cj.worker_fee_lkr > 150000 else "")}>{lkr(cj.worker_fee_lkr) if cj.worker_fee_lkr > 0 else "None stated"}</td> for cj in comp_jobs]}
                                    </tr>
                                    <tr>
                                        <td className="py-3 font-semibold text-muted-foreground">Visa Category</td>
                                        {[<td key={cj.id} className="py-3">{cj.contract_type or "Employment visa"}</td> for cj in comp_jobs]}
                                    </tr>
                                    <tr>
                                        <td className="py-3 font-semibold text-muted-foreground">Contract Duration</td>
                                        {[<td key={cj.id} className="py-3">{(f"{cj.contract_months} months") if cj.contract_months else "Not stated"}</td> for cj in comp_jobs]}
                                    </tr>
                                    <tr>
                                        <td className="py-3 font-semibold text-muted-foreground">Accommodation</td>
                                        {[<td key={cj.id} className="py-3">{cj.accommodation or "Not stated"}</td> for cj in comp_jobs]}
                                    </tr>
                                    <tr>
                                        <td className="py-3 font-semibold text-muted-foreground">Safety Assessment</td>
                                        {[<td key={cj.id} className="py-3"><SafetyIndicator risk={risk_of(cj.band, cj.score)}/></td> for cj in comp_jobs]}
                                    </tr>
                                    <tr>
                                        <td className="py-3 font-semibold text-muted-foreground">Candidate Match</td>
                                        {[<td key={cj.id} className="py-3">{if match_pct(matches, cj.id) >= 0 { <MatchMeter value={match_pct(matches, cj.id)}/>; } else { <span className="text-xs text-muted-foreground">Add profile</span>; }}</td> for cj in comp_jobs]}
                                    </tr>
                                    <tr>
                                        <td className="py-3 font-semibold text-muted-foreground">SLBFE Licence</td>
                                        {[<td key={cj.id} className="py-3 font-mono text-xs">{cj.licence_no} <VerifyBadge state="verified"/></td> for cj in comp_jobs]}
                                    </tr>
                                    <tr>
                                        <td className="py-3 font-semibold text-muted-foreground">Action</td>
                                        {[<td key={cj.id} className="py-3"><button onClick={lambda -> None { show_compare = False; open_job(cj.id); }} className="rounded bg-primary px-3 py-1 text-xs font-semibold text-primary-foreground hover:bg-primary-deep">View listing →</button></td> for cj in comp_jobs]}
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    }}
                </div>
            </div>
        }}
    </div>;
}
