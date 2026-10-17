"""Companies list + company page, ported from the layout-coder design; live SLBFE register data and graph-derived relations."""

import from "lucide-react" { ArrowLeft, Flag }
import from jobboard { ListAgencies, AddReview, AgencyView, JobView, ReviewView, PostResult }
import from .ui { risk_of, SafetyIndicator, VerifyBadge, LiveTag, EmptyState, PageHeader }

obj ReportRow {
    has job: str,
        rv: ReviewView;
}

def all_reports(ag: AgencyView) -> list[ReportRow] {
    rows: list[ReportRow] = [];
    for j in ag.jobs {
        for r in j.reviews {
            rows.append(ReportRow(job=j.title, rv=r));
        }
    }
    return rows;
}

def report_category(r: ReviewView) -> str {
    if r.kind == "positive" {
        return "Positive experience";
    }
    if r.kind == "fraud" and "impersonat" in r.reason.lower() {
        return "Impersonation of this agency";
    }
    if r.kind == "fraud" {
        return "Fraud allegation";
    }
    return "Other";
}

def:pub Companies(refresh: int) -> JsxElement {
    has agencies: list[AgencyView] = [],
        open_id: str = "",
        mode: str = "",
        job_id: str = "",
        role: str = "",
        text: str = "",
        evidence: str = "",
        sending: bool = False,
        message: str = "";

    async def load -> None {
        result = root spawn ListAgencies();
        agencies = result.reports;
    }

    async def submit -> None {
        sending = True;
        result = root spawn AddReview(job_id=job_id, author=role or "Worker", kind="fraud" if mode == "report" else "other",
            text=("[Correction request] " if mode == "correction" else "") + text, evidence=evidence);
        if result.reports {
            r: PostResult = result.reports[0];
            message = r.message + " " + "; ".join([s.detail for s in r.steps][:1]);
        }
        text = "";
        evidence = "";
        mode = "";
        sending = False;
        await load();
    }

    can with [refresh] entry {
        load();
    }

    opened = [a for a in agencies if a.id == open_id];

    if opened {
        c = opened[0];
        reports = all_reports(c);
        cats = ["Fraud allegation", "Impersonation of this agency", "Positive experience", "Other"];
        return <div>
            <button onClick={lambda -> None { open_id = ""; message = ""; }} className="inline-flex items-center gap-1 text-sm font-semibold text-muted-foreground hover:text-foreground"><ArrowLeft className="h-4 w-4"/> Companies</button>
            <header className="mt-6 grid gap-6 border-b border-border pb-8 lg:grid-cols-[1fr_340px]">
                <div>
                    <p className="eyebrow">Recruitment agency · SLBFE licensed</p>
                    <h1 className="mt-2 text-4xl font-extrabold leading-[0.95] md:text-6xl">{c.name}</h1>
                    <p className="mt-4 max-w-2xl text-muted-foreground">{f"Licence record matched against the live SLBFE register. {len(c.jobs)} verified listing(s), {c.reports} worker report(s), {c.credible_fraud} credible fraud report(s) against the agency itself."}</p>
                    {[<p key={i} className="mt-3 rounded-lg border border-primary/30 bg-secondary px-4 py-3 text-sm font-semibold text-primary-deep">{"Impersonation alert: " + w}</p> for (i, w) in enumerate(c.warnings[:1])]}
                </div>
                <dl className="rounded-xl border border-border bg-card p-5 text-sm shadow-card">
                    <div className="flex items-center justify-between"><dt className="eyebrow">Licence</dt><LiveTag label="Live SLBFE register"/></div>
                    <dd className="mt-2 flex items-center gap-2 font-mono">{c.licence_no} <VerifyBadge state="verified"/></dd>
                    <dt className="eyebrow mt-4">Valid until</dt><dd className="mt-1 font-mono">{c.valid_upto}</dd>
                    <dt className="eyebrow mt-4">Last checked</dt><dd className="mt-1 font-mono">{c.checked_at or "Never"}</dd>
                    <dt className="eyebrow mt-4">Registered contacts</dt><dd className="mt-1 font-mono text-xs">{", ".join(c.phones + ([c.email] if c.email else []))}</dd>
                    <dt className="eyebrow mt-4">Related entities</dt>
                    <dd className="mt-1 flex flex-wrap gap-1.5">
                        {[<span key={n} className="rounded border border-risk/40 px-2 py-0.5 font-mono text-xs font-medium text-risk">{n + " (impersonator)"}</span> for n in c.impersonator_numbers]}
                        <span className="rounded border border-border px-2 py-0.5 text-xs font-medium">{f"{len(c.related_checks)} community check(s) name this agency"}</span>
                    </dd>
                </dl>
            </header>
            <div className="grid gap-10 py-8 lg:grid-cols-[1fr_1.4fr]">
                <section>
                    <h2 className="text-xl font-bold">Listings</h2>
                    <ul className="mt-3 divide-y divide-border rounded-xl border border-border bg-card">
                        {if len(c.jobs) == 0 { <li className="px-4 py-3 text-sm text-muted-foreground">No listings yet.</li> }}
                        {[<li key={j.id} className="flex items-center justify-between gap-3 px-4 py-3"><span><span className="block text-sm font-semibold">{j.title}</span><span className="text-xs text-muted-foreground">{j.country + " · " + j.posted_at}</span></span><SafetyIndicator risk={risk_of(j.band, j.score)} compact={True}/></li> for j in c.jobs]}
                    </ul>
                    <h2 className="mt-8 text-xl font-bold">Report categories</h2>
                    <dl className="mt-3 grid grid-cols-2 gap-px overflow-hidden rounded-xl border border-border bg-border">
                        {[<div key={k} className="bg-card p-4"><dd className={"font-display text-3xl font-bold " + ("text-risk" if k == "Fraud allegation" and len([r for r in reports if report_category(r.rv) == k]) > 0 else "")}>{str(len([r for r in reports if report_category(r.rv) == k]))}</dd><dt className="text-xs text-muted-foreground">{k}</dt></div> for k in cats]}
                    </dl>
                    <h2 className="mt-8 text-xl font-bold">Community checks naming this agency</h2>
                    <ul className="mt-3 space-y-1 font-mono text-xs text-muted-foreground">{[<li key={k}>{r}</li> for (k, r) in enumerate(c.related_checks)]}</ul>
                </section>
                <section>
                    <div className="flex flex-wrap items-center justify-between gap-2">
                        <h2 className="text-xl font-bold">Moderated worker reports</h2>
                        <div className="flex gap-2">
                            <button onClick={lambda -> None { mode = "" if mode == "report" else "report"; job_id = c.jobs[0].id if c.jobs else ""; }} className="inline-flex items-center gap-1.5 rounded-md bg-primary px-3 py-2 text-xs font-semibold text-primary-foreground"><Flag className="h-3.5 w-3.5"/> Submit report</button>
                            <button onClick={lambda -> None { mode = "" if mode == "correction" else "correction"; job_id = c.jobs[0].id if c.jobs else ""; }} className="rounded-md border border-border bg-card px-3 py-2 text-xs font-semibold">Request correction</button>
                        </div>
                    </div>
                    <p className="mt-1 text-xs text-muted-foreground">Each report is checked by the Review Verifier agent. An unverified report is not an established fact; impersonation reports never lower the agency's own score.</p>
                    {if mode and len(c.jobs) > 0 {
                        <div className="mt-4 space-y-3 rounded-xl border border-primary/40 bg-card p-4 rise-in">
                            <p className="text-sm font-semibold">{"Share your experience" if mode == "report" else "Request a correction to this profile"}</p>
                            <div className="grid gap-3 sm:grid-cols-2">
                                <label className="text-xs font-semibold">Listing<select value={job_id} onChange={lambda (e: ChangeEvent) { job_id = e.target.value; }} className="mt-1 h-10 w-full rounded-md border border-input bg-card px-2 text-sm font-normal">{[<option key={j.id} value={j.id}>{j.title + " · " + j.country}</option> for j in c.jobs]}</select></label>
                                <label className="text-xs font-semibold">Your role (optional)<input value={role} onChange={lambda (e: ChangeEvent) { role = e.target.value; }} className="mt-1 h-10 w-full rounded-md border border-input bg-card px-2 text-sm font-normal"/></label>
                            </div>
                            <label className="block text-xs font-semibold">What happened?<textarea value={text} onChange={lambda (e: ChangeEvent) { text = e.target.value; }} rows={3} className="mt-1 w-full rounded-md border border-input bg-card p-2 text-sm font-normal"/></label>
                            <label className="block text-xs font-semibold">Evidence<input value={evidence} onChange={lambda (e: ChangeEvent) { evidence = e.target.value; }} placeholder="Receipt, bank slip details, chat excerpt" className="mt-1 h-10 w-full rounded-md border border-input bg-card px-2 text-sm font-normal"/></label>
                            <p className="text-xs text-muted-foreground">{"Don't include your NIC, passport number or phone number."}</p>
                            <button disabled={sending} onClick={lambda { submit(); }} className="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground">{"Review Verifier checking..." if sending else "Submit for moderation"}</button>
                        </div>
                    }}
                    {if message { <p className="mt-3 rounded-md bg-secondary px-3 py-2 text-xs text-primary-deep">{message}</p> }}
                    {if len(reports) == 0 {
                        <div className="mt-4"><EmptyState title="No reports yet" body="No worker has reported on this company. That is not evidence either way."/></div>
                    } else {
                        <ol className="mt-4 border-l border-border">
                            {[
                                <li key={row.rv.id} className="relative pb-6 pl-6">
                                    <span className={"absolute -left-[5px] top-1.5 h-2.5 w-2.5 rounded-sm " + ("bg-safe" if row.rv.kind == "positive" else ("bg-sky" if "impersonat" in row.rv.reason.lower() else "bg-caution"))}></span>
                                    <div className="flex flex-wrap items-center gap-2 text-xs">
                                        <span className="font-mono text-muted-foreground">{row.rv.created_at}</span>
                                        <span className="font-semibold">{report_category(row.rv)}</span>
                                        <span className="rounded bg-muted px-1.5 py-0.5">{"Verified by agent" if row.rv.status == "credible" else "Unverified"}</span>
                                        <span className="rounded border border-border px-1.5 py-0.5">{f"Credibility: {row.rv.credibility}/100"}</span>
                                    </div>
                                    <p className="mt-1.5 text-sm">{row.rv.text}</p>
                                    <p className="mt-1 text-xs text-muted-foreground">{"— " + row.rv.author + " · " + row.job}</p>
                                    {if row.rv.agency_response {
                                        <blockquote className="mt-2 border-l-2 border-primary pl-4 text-sm"><p className="eyebrow mb-1">Agency response</p>{row.rv.agency_response}</blockquote>
                                    }}
                                </li>
                                for row in reports
                            ]}
                        </ol>
                    }}
                </section>
            </div>
        </div>;
    }

    return <div>
        <PageHeader eyebrow="Company intelligence" title="Know who you're" accent="dealing with."><LiveTag label="Live SLBFE register"/></PageHeader>
        {if len(agencies) == 0 {
            <EmptyState title="No agencies verified yet" body="Agencies appear here after a check or a job posting finds them on the SLBFE register."/>
        } else {
            <div className="overflow-x-auto rounded-xl border border-border bg-card shadow-sm">
                <table className="w-full min-w-[640px] text-sm">
                    <thead className="eyebrow border-b border-border bg-muted/40 text-left">
                        <tr>
                            <th className="px-5 py-3.5">Agency Name</th>
                            <th>Accreditation</th>
                            <th>Licence No.</th>
                            <th>Validity</th>
                            <th>Listings</th>
                            <th>Worker Reports</th>
                            <th className="pr-5 text-right">Action</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-border">
                        {[
                            <tr key={a.id} onClick={lambda -> None { open_id = a.id; }} className="cursor-pointer transition-colors hover:bg-muted/60">
                                <td className="px-5 py-3.5">
                                    <span className="font-semibold text-foreground hover:text-primary transition-colors">{a.name}</span>
                                    <p className="font-mono text-xs text-muted-foreground">{", ".join(a.phones[:2])}</p>
                                </td>
                                <td><VerifyBadge state="verified" prefix="SLBFE"/></td>
                                <td className="font-mono text-xs font-semibold">{a.licence_no}</td>
                                <td className="font-mono text-xs text-muted-foreground">{a.valid_upto}</td>
                                <td className="font-mono text-xs">{str(len(a.jobs))}</td>
                                <td className="font-mono text-xs">{str(a.reports)}</td>
                                <td className="pr-5 text-right font-medium text-primary">Open profile →</td>
                            </tr>
                            for a in agencies
                        ]}
                    </tbody>
                </table>
            </div>
        }}
    </div>;
}
