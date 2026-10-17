"""Investigate (check an offer), ported from the layout-coder design and driven by the real agent team."""

import from "lucide-react" { Check, Loader2, RotateCcw, FileText, Copy, Landmark, Scale }
import from agents { Investigate, CaseReport, Step }
import from rules { RedFlag }
import from .ui { risk_of, SafetyIndicator, FindingItem, LiveTag, PageHeader }

glob SAMPLES: list[list[str]] = [
    ["Thailand IT job", "URGENT HIRING!!! IT / Data Entry jobs in THAILAND\nSalary USD 1500 per month + free accommodation + food\nNo experience needed, basic English and typing only.\nAir ticket FREE. Travel on tourist visa, company will change to work visa after arrival.\nOnly 5 seats left - pay Rs. 150,000 processing fee to confirm your seat.\nDeposit to Commercial Bank account 8012345678 (K. Perera). Send slip on WhatsApp +94 76 555 1234"],
    ["Agency impersonation", "A T C GLOBAL HOLDINGS (PVT) LTD - Licence No 3500\nQatar - House Driver vacancies. Salary QAR 1800. Employment visa.\nRegistration fee Rs. 75,000 must be paid before interview to reserve your place.\nContact our recruitment officer on WhatsApp 0789 123 456"],
    ["Vague WhatsApp message", "Hi brother, good job in Saudi Arabia, driver, salary SAR 2000. Our sir can arrange everything quickly. Send your passport copy and Rs. 50,000 to start the process. Call Kamal 0751112233"],
    ["Genuine offer", "A T C GLOBAL HOLDINGS (PVT) LTD (SLBFE Licence No 3500)\nVacancy: Light vehicle driver - Qatar. Employment visa sponsored by employer.\nSalary QAR 2000 + accommodation. 2-year contract provided before departure.\nAll payments only at our Nugegoda office with official receipt, after you sign the contract.\nCall 0112818268 or email info@atcs.lk"]
];

"""Agent roster: display name, step-agent key, description."""
glob AGENTS: list[list[str]] = [
    ["Extraction", "Extractor", "Reads salary, visa, fees, agency and licence details"],
    ["Supervisor cross-check", "Supervisor", "Re-reads the text with plain patterns and fixes what the Extractor missed"],
    ["Official verification", "Lead Investigator", "Checks the live SLBFE register, registered contacts and community reports"],
    ["Graph investigation", "Duplicate Detector", "Looks for the same ad reposted with different numbers"],
    ["Contract analysis", "expert", "Trafficking, contract and fee experts quote exact language"],
    ["Independent critique", "Critic", "Challenges findings and drops any claim not literally in the offer"],
    ["Courtroom", "Prosecutor", "Prosecutor and Defender argue; the Judge decides"],
    ["Advice", "Advisor", "Drafts questions and next steps"]
];

def steps_for(steps: list[Step], key: str) -> list[Step] {
    return [s for s in steps if key in s.agent];
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

def verdict_copy(risk: str) -> str {
    if risk == "low" {
        return "No serious issues found in the text provided.";
    }
    if risk == "moderate" {
        return "Some concerns. Get answers before you continue.";
    }
    if risk == "high" {
        return "Serious risks. Do not pay until each is resolved.";
    }
    return "Do not pay or sign. Multiple critical risks.";
}

def:pub CheckOffer(onChecked: Callable[[], None]) -> JsxElement {
    has text: str = "",
        busy: bool = False,
        started: float = 0.0,
        now: float = 0.0,
        outcome: CaseReport | None = None,
        answers: list[str] = [],
        sample_i: int = 0,
        copied: bool = False,
        error: str = "";

    can with [busy] entry {
        if busy {
            started = Date.now();
            now = Date.now();
            timer = setInterval(lambda { now = Date.now(); }, 400);
            return lambda { clearInterval(timer); };
        }
    }

    async def run(extra: list[str]) -> None {
        if len(text.strip()) < 40 {
            error = "Paste at least a few sentences of the advert or contract.";
            return;
        }
        error = "";
        copied = False;
        busy = True;
        if not extra {
            outcome = None;
            answers = [];
        }
        result = root spawn Investigate(text=text, answers=extra);
        if result.reports {
            outcome = result.reports[0];
        } else {
            error = "The agents could not finish. Please try again.";
        }
        busy = False;
        onChecked();
    }

    def answer_pairs -> list[str] {
        qs: list[str] = outcome.questions if outcome is not None else [];
        return [f"Q: {q} A: {answers[i] if i < len(answers) else 'unknown'}" for (i, q) in enumerate(qs)];
    }

    def next_sample {
        text = SAMPLES[sample_i % len(SAMPLES)][1];
        sample_i = sample_i + 1;
    }

    def copy_report {
        if outcome is not None and outcome.advice is not None {
            navigator.clipboard.writeText(outcome.advice.report_draft or ("SafeRata report\nRisk: " + outcome.band + "\n\n" + text));
            copied = True;
        }
    }

    stage = int((now - started) / 2600) if busy else 99;
    all_steps: list[Step] = outcome.steps if outcome is not None else [];
    done = outcome is not None and outcome.status == "done" and not busy;
    risk = risk_of(outcome.band, outcome.score) if (outcome is not None and outcome.status == "done") else "low";

    return <div>
        <PageHeader eyebrow="Trust investigation" title="Check an offer" accent="before you pay.">
            <LiveTag label="Live agents · official SLBFE register"/>
        </PageHeader>

        <div className="grid gap-6 lg:grid-cols-[1.1fr_1fr]">
            <div>
                <label className="eyebrow">Job advertisement or contract text</label>
                <textarea id="offer" value={text} onChange={lambda (e: ChangeEvent) { text = e.target.value; }} disabled={busy} rows={10}
                    placeholder="Paste the WhatsApp message, Facebook post or contract clause you received…"
                    className="mt-2 w-full resize-y rounded-xl border border-input bg-card p-4 font-mono text-sm leading-relaxed shadow-card outline-none focus:border-primary"/>
                {if error { <p className="mt-2 text-sm font-medium text-risk">{error}</p> }}
                <div className="mt-3 flex flex-wrap gap-2">
                    <button id="investigate" onClick={lambda { run([]); }} disabled={busy} className="inline-flex h-11 items-center gap-2 rounded-md bg-primary px-5 text-sm font-semibold text-primary-foreground hover:bg-primary-deep disabled:opacity-60">
                        {if busy { <Loader2 className="h-4 w-4 animate-spin"/> }} Investigate offer
                    </button>
                    <button onClick={lambda -> None { next_sample(); }} disabled={busy} className="h-11 rounded-md border border-border bg-card px-4 text-sm font-semibold">{"Use sample offer: " + SAMPLES[sample_i % len(SAMPLES)][0]}</button>
                    {if done { <button onClick={lambda -> None { outcome = None; text = ""; }} className="inline-flex h-11 items-center gap-1.5 px-3 text-sm font-semibold text-muted-foreground"><RotateCcw className="h-4 w-4"/> New</button> }}
                </div>
            </div>

            <ol className="relative rounded-xl border border-border bg-card p-5 shadow-card">
                <p className="eyebrow mb-4">Agent activity</p>
                {[
                    <li key={i} className="relative grid grid-cols-[28px_1fr] gap-3 pb-4 last:pb-0">
                        {if i < len(AGENTS) - 1 {
                            <span className={"absolute left-[13px] top-7 h-[calc(100%-20px)] w-px " + ("bg-primary" if (busy and i < stage) or (done and len(steps_for(all_steps, a[1])) > 0) else "bg-border")}></span>
                        }}
                        {if (busy and i < stage) or (done and len(steps_for(all_steps, a[1])) > 0) {
                            <span className="z-10 grid h-7 w-7 place-items-center rounded-md border border-primary bg-primary text-xs text-primary-foreground"><Check className="h-3.5 w-3.5"/></span>
                        } elif busy and i == min(stage, len(AGENTS) - 1) {
                            <span className="z-10 grid h-7 w-7 place-items-center rounded-md border border-primary text-xs text-primary"><Loader2 className="h-3.5 w-3.5 animate-spin"/></span>
                        } else {
                            <span className="z-10 grid h-7 w-7 place-items-center rounded-md border border-border text-xs text-muted-foreground">{str(i + 1)}</span>
                        }}
                        <div>
                            <p className="flex items-baseline justify-between gap-2 text-sm font-semibold">{a[0]}
                                {if done and len(steps_for(all_steps, a[1])) > 0 { <span className="font-mono text-[10px] font-normal text-muted-foreground">{f"{len(steps_for(all_steps, a[1]))} step(s) · live"}</span> }}
                            </p>
                            <p className="text-xs text-muted-foreground">{steps_for(all_steps, a[1])[-1].detail[:150] if (done and len(steps_for(all_steps, a[1])) > 0) else a[2]}</p>
                        </div>
                    </li>
                    for (i, a) in enumerate(AGENTS)
                ]}
            </ol>
        </div>

        {if not busy and outcome is not None and outcome.status == "needs_input" {
            <div className="mt-10 rounded-xl border border-caution/60 bg-caution-soft p-5 rise-in">
                <h3 className="font-bold">Missing information</h3>
                <p className="mt-1 text-sm text-muted-foreground">The Lead Investigator paused because a decisive fact is missing.</p>
                {[
                    <div key={i} className="mt-3">
                        <p className="text-sm font-semibold">{"— " + q}</p>
                        <input value={answers[i] if i < len(answers) else ""}
                            onChange={lambda (e: ChangeEvent) {
                                copy = [x for x in answers];
                                while len(copy) <= i { copy.append(""); }
                                copy[i] = e.target.value;
                                answers = copy;
                            }}
                            className="mt-1 h-10 w-full rounded-md border border-input bg-card px-3 text-sm"/>
                    </div>
                    for (i, q) in enumerate(outcome.questions)
                ]}
                <button onClick={lambda { run(answer_pairs()); }} className="mt-4 inline-flex h-10 items-center rounded-md bg-primary px-4 text-sm font-semibold text-primary-foreground">Continue investigation</button>
            </div>
        }}

        {if outcome is not None and done {
            <div className="mt-10 space-y-8 rise-in">
                <section className={"grid gap-6 rounded-2xl p-7 md:grid-cols-[1fr_auto] " + ("bg-safe-soft" if risk == "low" else ("bg-caution-soft" if risk == "moderate" else "bg-ink text-ink-foreground"))}>
                    <div>
                        <p className="eyebrow">Verdict</p>
                        <h2 className="mt-2 text-3xl font-bold leading-tight md:text-4xl">{verdict_copy(risk)}</h2>
                        <p className={"mt-3 text-sm " + ("text-ink-foreground/70" if risk in ["high", "critical"] else "text-muted-foreground")}>{outcome.judge}</p>
                    </div>
                    <dl className="flex gap-8">
                        <div><dt className="eyebrow">Risk</dt><dd className="mt-2"><SafetyIndicator risk={risk}/></dd><dd className="mt-1 font-mono text-xs">{f"{outcome.score}/100"}</dd></div>
                        <div><dt className="eyebrow">Confidence</dt><dd className="mt-1 font-display text-3xl font-bold">{f"{outcome.confidence}%"}</dd></div>
                    </dl>
                </section>

                <div className="grid gap-6 lg:grid-cols-[1.4fr_1fr]">
                    <section>
                        <h3 className="mb-2 text-lg font-bold">Findings <span className="font-mono text-sm font-normal text-muted-foreground">{str(len(outcome.flags))}</span></h3>
                        {if len(outcome.flags) > 0 {
                            <ul className="rounded-xl border border-border bg-card px-4">
                                {[<FindingItem key={i} title={f"{f.title} (+{f.points})"} risk={finding_risk(f.points)} kind={finding_kind(f.source)} source={f.source + " · " + f.agent} excerpt={f.evidence} why={f.explanation} open_default={i == 0}/> for (i, f) in enumerate(outcome.flags)]}
                            </ul>
                        } else {
                            <p className="text-sm text-muted-foreground">No supported findings. That is not proof the offer is safe.</p>
                        }}
                        {if len(outcome.removed) > 0 {
                            <p className="mt-2 text-xs text-muted-foreground">{f"Independent critique removed {len(outcome.removed)} unsupported claim(s): " + "; ".join(outcome.removed)}</p>
                        }}
                        <p className="mt-2 font-mono text-[11px] text-muted-foreground">{f"Official register & rules {outcome.hard_points} pts + agent judgement {outcome.soft_points} pts (capped at 20)"}</p>
                    </section>
                    <section className="space-y-6">
                        <div className="rounded-xl border border-border bg-card p-5">
                            <h3 className="font-bold">Extracted evidence</h3>
                            {if outcome.facts is not None {
                                <dl className="mt-3 divide-y divide-border text-sm">
                                    <div className="flex justify-between gap-3 py-2"><dt className="text-muted-foreground">Job</dt><dd className="text-right font-mono text-xs">{(outcome.facts.job_title or "Unavailable") + (" · " + outcome.facts.country if outcome.facts.country else "")}</dd></div>
                                    <div className="flex justify-between gap-3 py-2"><dt className="text-muted-foreground">Salary</dt><dd className="text-right font-mono text-xs">{f"{outcome.facts.salary_currency} {outcome.facts.salary_amount:,.0f}" if outcome.facts.salary_amount > 0 else "Unavailable"}</dd></div>
                                    <div className="flex justify-between gap-3 py-2"><dt className="text-muted-foreground">Visa</dt><dd className="text-right font-mono text-xs">{outcome.facts.visa_type or "Unavailable"}</dd></div>
                                    <div className="flex justify-between gap-3 py-2"><dt className="text-muted-foreground">Fee requested</dt><dd className="text-right font-mono text-xs">{", ".join([f"{x.currency} {x.amount:,.0f}" for x in outcome.facts.fees]) or "Unavailable"}</dd></div>
                                    <div className="flex justify-between gap-3 py-2"><dt className="text-muted-foreground">Licence</dt><dd className="text-right font-mono text-xs">{outcome.facts.licence_no or "Unavailable"}</dd></div>
                                    <div className="flex justify-between gap-3 py-2"><dt className="text-muted-foreground">Agency</dt><dd className="text-right font-mono text-xs">{outcome.facts.agency_name or "Unavailable"}</dd></div>
                                    <div className="flex justify-between gap-3 py-2"><dt className="text-muted-foreground">Contacts</dt><dd className="text-right font-mono text-xs">{", ".join(outcome.facts.phones + outcome.facts.emails) or "Unavailable"}</dd></div>
                                </dl>
                            }}
                        </div>
                        <div className="rounded-xl border border-border bg-card p-5">
                            <h3 className="flex items-center gap-2 font-bold"><Landmark className="h-4 w-4 text-primary"/> SLBFE register</h3>
                            {if outcome.agency is not None {
                                <div className="mt-2 text-sm">
                                    <p className="font-semibold">{outcome.agency.name}</p>
                                    <p className="font-mono text-xs text-muted-foreground">{f"Licence {outcome.agency.licence_no} · valid until {outcome.agency.valid_upto}"}</p>
                                    <p className="mt-1 font-mono text-xs text-muted-foreground">{"Registered: " + ", ".join(outcome.agency.phones)}</p>
                                </div>
                            }}
                            <p className="mt-2 eyebrow">{"Status: " + (outcome.register_status or "not checked")}</p>
                            {if outcome.alerts_sent > 0 { <p className="mt-2 text-xs font-semibold text-primary-deep">{f"Network Guardian warned {outcome.alerts_sent} earlier check(s)."}</p> }}
                        </div>
                    </section>
                </div>

                <section className="grid gap-6 rounded-2xl border border-border bg-card p-6 shadow-card md:grid-cols-2">
                    <div><p className="eyebrow flex items-center gap-1"><Scale className="h-3 w-3"/> Prosecutor</p><p className="mt-2 text-sm">{outcome.prosecution}</p></div>
                    <div><p className="eyebrow flex items-center gap-1"><Scale className="h-3 w-3"/> Defender</p><p className="mt-2 text-sm">{outcome.defence}</p></div>
                </section>

                {if outcome.advice is not None {
                    <section className="grid gap-6 border-t border-border pt-8 md:grid-cols-2">
                        <div>
                            <h3 className="text-lg font-bold">Ask before paying or signing</h3>
                            <ol className="mt-3 list-decimal space-y-2 pl-5 text-sm">{[<li key={k}>{q}</li> for (k, q) in enumerate(outcome.advice.questions_to_ask)]}</ol>
                        </div>
                        <div>
                            <h3 className="text-lg font-bold">Next steps</h3>
                            <ul className="mt-3 space-y-2 text-sm text-muted-foreground">{[<li key={k}>{s}</li> for (k, s) in enumerate(outcome.advice.next_steps)]}</ul>
                            <button onClick={lambda -> None { copy_report(); }} className="mt-4 inline-flex items-center gap-2 rounded-md border border-border bg-card px-4 py-2 text-sm font-semibold">
                                <FileText className="h-4 w-4"/> {"Report copied" if copied else "Draft report to SLBFE (1989)"} <Copy className="h-3.5 w-3.5 text-muted-foreground"/>
                            </button>
                        </div>
                    </section>
                }}

                <details className="rounded-xl border border-border bg-card p-5 text-sm">
                    <summary className="cursor-pointer font-semibold">{f"Full agent log ({len(outcome.steps)} steps) and sources"}</summary>
                    <ol className="mt-3 list-decimal space-y-1 pl-5 font-mono text-xs">{[<li key={k}><span className="font-semibold">{s.agent}</span>{" · " + s.action + ": " + s.detail}</li> for (k, s) in enumerate(outcome.steps)]}</ol>
                    <ul className="mt-3 space-y-1 text-xs text-muted-foreground">{[<li key={k}><span className="font-semibold text-foreground">{src.name}</span>{": " + src.detail}</li> for (k, src) in enumerate(outcome.sources)]}</ul>
                </details>
            </div>
        }}
    </div>;
}
