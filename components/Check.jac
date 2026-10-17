"""Check an offer: paste -> agent activity -> verdict (layout from the layout-coder design, real backend)."""

import from agents { Investigate, CaseReport, Step }
import from rules { RedFlag }
import from .theme {
    INK, MUTED_INK, PRIMARY, PRIMARY_DEEP, ACCENT, MUTED, BORDER, RISK, RISK_SOFT, CARD, LABEL,
    band_label, band_fg, band_bg, trust_color
}

glob SAMPLES: list[list[str]] = [
    ["Thailand IT job", "URGENT HIRING!!! IT / Data Entry jobs in THAILAND\nSalary USD 1500 per month + free accommodation + food\nNo experience needed, basic English and typing only.\nAir ticket FREE. Travel on tourist visa, company will change to work visa after arrival.\nOnly 5 seats left - pay Rs. 150,000 processing fee to confirm your seat.\nDeposit to Commercial Bank account 8012345678 (K. Perera). Send slip on WhatsApp +94 76 555 1234"],
    ["Agency impersonation", "A T C GLOBAL HOLDINGS (PVT) LTD - Licence No 3500\nQatar - House Driver vacancies. Salary QAR 1800. Employment visa.\nRegistration fee Rs. 75,000 must be paid before interview to reserve your place.\nContact our recruitment officer on WhatsApp 0789 123 456"],
    ["Vague WhatsApp message", "Hi brother, good job in Saudi Arabia, driver, salary SAR 2000. Our sir can arrange everything quickly. Send your passport copy and Rs. 50,000 to start the process. Call Kamal 0751112233"],
    ["Genuine offer", "A T C GLOBAL HOLDINGS (PVT) LTD (SLBFE Licence No 3500)\nVacancy: Light vehicle driver - Qatar. Employment visa sponsored by employer.\nSalary QAR 2000 + accommodation. 2-year contract provided before departure.\nAll payments only at our Nugegoda office with official receipt, after you sign the contract.\nCall 0112818268 or email info@atcs.lk"]
];

"""The agent roster shown in the activity panel: display name, the step agents that belong to it, what it does."""
glob ROSTER: list[list[str]] = [
    ["Extraction", "Extractor", "Reads salary, visa, fees, agency and licence details"],
    ["Supervisor cross-check", "Supervisor", "Re-reads the text with plain patterns and fixes what the Extractor missed"],
    ["Official verification", "Lead Investigator", "Checks the live SLBFE register, registered contacts and community reports"],
    ["Duplicate detector", "Duplicate Detector", "Looks for the same ad reposted with different numbers"],
    ["Specialist review", "expert", "Trafficking, contract and fee experts quote exact language"],
    ["Independent critique", "Critic", "Drops any claim that is not literally in the offer"],
    ["Courtroom", "Prosecutor", "Prosecutor and Defender argue; the Judge decides"],
    ["Advice", "Advisor", "Drafts questions, next steps and a report"]
];

def steps_for(steps: list[Step], key: str) -> list[Step] {
    return [s for s in steps if key in s.agent];
}

def:pub CheckOffer(onChecked: Callable[[], None]) -> JsxElement {
    has text: str = "",
        busy: bool = False,
        started: float = 0.0,
        now: float = 0.0,
        outcome: CaseReport | None = None,
        answers: list[str] = [],
        error: str = "";

    can with [busy] entry {
        if busy {
            started = Date.now();
            now = Date.now();
            timer = setInterval(lambda { now = Date.now(); }, 500);
            return lambda { clearInterval(timer); };
        }
    }

    async def run(extra: list[str]) -> None {
        if not text.strip() {
            error = "Paste an offer first.";
            return;
        }
        error = "";
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

    stage = int((now - started) / 2800) if busy else 99;

    return <div style={{"display": "grid", "gridTemplateColumns": "minmax(0, 5fr) minmax(0, 7fr)", "gap": "18px", "alignItems": "start"}}>
        <div style={{"display": "flex", "flexDirection": "column", "gap": "16px"}}>
            <div style={CARD}>
                <div style={LABEL}>Job advertisement or contract text</div>
                <textarea id="offer" value={text} rows={9}
                    onChange={lambda (e: ChangeEvent) { text = e.target.value; }}
                    placeholder="Paste the WhatsApp message, Facebook post or contract clause you received..."
                    style={{"width": "100%", "boxSizing": "border-box", "marginTop": "8px", "padding": "12px", "borderRadius": "10px", "border": "1px solid " + BORDER, "fontSize": "14px", "fontFamily": "inherit", "background": "#fbfcfe"}}/>
                <div style={{"display": "flex", "gap": "6px", "flexWrap": "wrap", "marginTop": "8px"}}>
                    {[
                        <button key={i} onClick={lambda -> None { text = smp[1]; }}
                            style={{"background": MUTED, "border": "1px solid " + BORDER, "borderRadius": "999px", "padding": "4px 10px", "fontSize": "12px", "color": INK, "cursor": "pointer"}}>{smp[0]}</button>
                        for (i, smp) in enumerate(SAMPLES)
                    ]}
                </div>
                <button id="investigate" disabled={busy} onClick={lambda { run([]); }}
                    style={{"marginTop": "12px", "width": "100%", "background": PRIMARY, "color": "white", "border": "none", "borderRadius": "10px", "padding": "12px", "fontWeight": "700", "fontSize": "15px", "cursor": "pointer"}}>
                    {"Agents investigating..." if busy else "Investigate offer"}
                </button>
                {if error {
                    <p style={{"color": RISK, "marginBottom": "0"}}>{error}</p>
                }}
            </div>

            <div style={CARD}>
                <div style={LABEL}>Agent activity</div>
                {[
                    <div key={i} style={{"display": "flex", "gap": "10px", "padding": "9px 0", "borderBottom": "1px solid " + MUTED}}>
                        <span style={{"width": "22px", "height": "22px", "borderRadius": "999px", "flexShrink": "0", "display": "flex", "alignItems": "center", "justifyContent": "center", "fontSize": "12px", "fontWeight": "700",
                            "background": (PRIMARY if (busy and i == min(stage, len(ROSTER) - 1)) else (ACCENT if (busy and i < stage) or (not busy and outcome is not None and len(steps_for(outcome.steps, r[1])) > 0) else MUTED)),
                            "color": ("white" if (busy and i == min(stage, len(ROSTER) - 1)) else PRIMARY_DEEP)}}>
                            {"✓" if (busy and i < stage) or (not busy and outcome is not None and len(steps_for(outcome.steps, r[1])) > 0) else str(i + 1)}
                        </span>
                        <div style={{"minWidth": "0"}}>
                            <div style={{"fontWeight": "600", "fontSize": "14px"}}>{r[0]}</div>
                            <div style={{"fontSize": "12px", "color": MUTED_INK}}>
                                {(steps_for(outcome.steps, r[1])[-1].detail[:120] if (outcome is not None and not busy and len(steps_for(outcome.steps, r[1])) > 0) else r[2])}
                            </div>
                        </div>
                    </div>
                    for (i, r) in enumerate(ROSTER)
                ]}
            </div>
        </div>

        <div style={{"display": "flex", "flexDirection": "column", "gap": "16px"}}>
            {if outcome is None and not busy {
                <div style={CARD}>
                    <div style={LABEL}>Verdict</div>
                    <h2 style={{"margin": "8px 0 4px", "fontSize": "26px"}}>Check an offer before you pay.</h2>
                    <p style={{"color": MUTED_INK, "margin": "0"}}>Paste any job offer. The agents verify the agency on the live SLBFE register, compare its contact numbers with the registered ones, search earlier community reports, argue the case for and against, and tell you exactly what to ask before paying anything.</p>
                </div>
            }}
            {if busy {
                <div style={CARD}>
                    <div style={LABEL}>Verdict</div>
                    <p style={{"color": MUTED_INK}}>The agents are working. Every finding will quote the exact words from the offer.</p>
                </div>
            }}

            {if not busy and outcome is not None and outcome.status == "needs_input" {
                <div style={{"background": "#ffffff", "border": "2px solid #c27c0e", "borderRadius": "14px", "padding": "18px"}}>
                    <div style={LABEL}>Missing information</div>
                    <p style={{"margin": "6px 0 10px", "color": MUTED_INK}}>The Lead Investigator paused because a decisive fact is missing.</p>
                    {[
                        <div key={i} style={{"marginBottom": "10px"}}>
                            <div style={{"fontWeight": "600"}}>{q}</div>
                            <input value={answers[i] if i < len(answers) else ""}
                                onChange={lambda (e: ChangeEvent) {
                                    copy = [a for a in answers];
                                    while len(copy) <= i { copy.append(""); }
                                    copy[i] = e.target.value;
                                    answers = copy;
                                }}
                                style={{"width": "100%", "boxSizing": "border-box", "padding": "9px", "borderRadius": "8px", "border": "1px solid " + BORDER, "marginTop": "4px"}}/>
                        </div>
                        for (i, q) in enumerate(outcome.questions)
                    ]}
                    <button onClick={lambda { run(answer_pairs()); }}
                        style={{"background": "#c27c0e", "color": "white", "border": "none", "borderRadius": "10px", "padding": "10px 16px", "fontWeight": "700"}}>Continue investigation</button>
                </div>
            }}

            {if not busy and outcome is not None and outcome.status == "done" {
                <div style={{"display": "flex", "flexDirection": "column", "gap": "16px"}}>
                    <div style={{"background": band_bg(outcome.band), "border": "1px solid " + band_fg(outcome.band), "borderRadius": "14px", "padding": "18px"}}>
                        <div style={{"display": "flex", "justifyContent": "space-between", "gap": "12px", "flexWrap": "wrap"}}>
                            <div>
                                <div style={LABEL}>Verdict</div>
                                <div id="band" style={{"fontSize": "28px", "fontWeight": "800", "color": band_fg(outcome.band)}}>{band_label(outcome.band)}</div>
                            </div>
                            <div style={{"display": "flex", "gap": "22px"}}>
                                <div><div style={LABEL}>Risk</div><div style={{"fontSize": "24px", "fontWeight": "800"}}>{f"{outcome.score}/100"}</div></div>
                                <div><div style={LABEL}>Confidence</div><div style={{"fontSize": "24px", "fontWeight": "800"}}>{f"{outcome.confidence}%"}</div></div>
                            </div>
                        </div>
                        <div style={{"background": "rgba(0,0,0,0.08)", "borderRadius": "999px", "height": "8px", "marginTop": "10px"}}>
                            <div style={{"background": band_fg(outcome.band), "borderRadius": "999px", "height": "8px", "width": f"{outcome.score}%"}}></div>
                        </div>
                        <p style={{"margin": "10px 0 0"}}>{outcome.judge}</p>
                        <div style={{"fontSize": "12px", "color": MUTED_INK, "marginTop": "6px"}}>{f"Official register and rules {outcome.hard_points} pts + agent judgement {outcome.soft_points} pts (capped at 20)"}</div>
                    </div>

                    <div style={CARD}>
                        <div style={LABEL}>{f"Findings ({len(outcome.flags)})"}</div>
                        {if len(outcome.flags) == 0 {
                            <p style={{"color": MUTED_INK}}>No supported findings. That is not proof the offer is safe: verify the agency before paying.</p>
                        }}
                        {[
                            <div key={i} style={{"padding": "12px 0", "borderBottom": "1px solid " + MUTED}}>
                                <div style={{"display": "flex", "justifyContent": "space-between", "gap": "8px", "flexWrap": "wrap"}}>
                                    <b>{f.title}</b>
                                    <span style={{"display": "flex", "gap": "6px", "alignItems": "center"}}>
                                        <span style={{"background": trust_color(f.source), "color": "white", "borderRadius": "6px", "padding": "1px 7px", "fontSize": "11px"}}>{f.source}</span>
                                        <span style={{"fontSize": "12px", "color": MUTED_INK}}>{f"+{f.points}"}</span>
                                    </span>
                                </div>
                                <div style={{"borderLeft": "3px solid " + RISK, "background": RISK_SOFT, "padding": "6px 10px", "margin": "6px 0", "fontStyle": "italic", "fontSize": "14px"}}>{"\"" + f.evidence + "\""}</div>
                                <div style={{"fontSize": "14px", "color": MUTED_INK}}>{f.explanation}</div>
                            </div>
                            for (i, f) in enumerate(outcome.flags)
                        ]}
                        {if len(outcome.removed) > 0 {
                            <div style={{"fontSize": "12px", "color": MUTED_INK, "marginTop": "8px"}}>{f"Independent critique removed {len(outcome.removed)} unsupported claim(s): " + "; ".join(outcome.removed)}</div>
                        }}
                    </div>

                    <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "16px"}}>
                        <div style={CARD}>
                            <div style={LABEL}>Extracted evidence</div>
                            {if outcome.facts is not None {
                                <table style={{"width": "100%", "fontSize": "14px", "marginTop": "6px", "borderCollapse": "collapse"}}><tbody>
                                    <tr><td style={{"color": MUTED_INK, "padding": "3px 0"}}>Job</td><td>{(outcome.facts.job_title or "not stated") + (" - " + outcome.facts.country if outcome.facts.country else "")}</td></tr>
                                    <tr><td style={{"color": MUTED_INK, "padding": "3px 0"}}>Salary</td><td>{f"{outcome.facts.salary_amount:,.0f} {outcome.facts.salary_currency}" if outcome.facts.salary_amount > 0 else "not stated"}</td></tr>
                                    <tr><td style={{"color": MUTED_INK, "padding": "3px 0"}}>Visa</td><td>{outcome.facts.visa_type or "not stated"}</td></tr>
                                    <tr><td style={{"color": MUTED_INK, "padding": "3px 0"}}>Fees</td><td>{", ".join([f"{x.label} {x.amount:,.0f} {x.currency}" for x in outcome.facts.fees]) or "none found"}</td></tr>
                                    <tr><td style={{"color": MUTED_INK, "padding": "3px 0"}}>Agency</td><td>{outcome.facts.agency_name or "not named"}</td></tr>
                                    <tr><td style={{"color": MUTED_INK, "padding": "3px 0"}}>Licence</td><td>{outcome.facts.licence_no or "not printed"}</td></tr>
                                    <tr><td style={{"color": MUTED_INK, "padding": "3px 0"}}>Contacts</td><td>{", ".join(outcome.facts.phones + outcome.facts.emails) or "none"}</td></tr>
                                </tbody></table>
                            }}
                        </div>
                        <div style={CARD}>
                            <div style={LABEL}>SLBFE register (live)</div>
                            {if outcome.agency is not None {
                                <div style={{"fontSize": "14px", "marginTop": "6px"}}>
                                    <div style={{"fontWeight": "700"}}>{outcome.agency.name}</div>
                                    <div>{f"Licence {outcome.agency.licence_no}, valid until {outcome.agency.valid_upto}"}</div>
                                    <div style={{"color": MUTED_INK}}>{"Registered phones: " + ", ".join(outcome.agency.phones)}</div>
                                    <div style={{"marginTop": "6px", "fontWeight": "600", "color": PRIMARY_DEEP}}>{"Status: " + outcome.register_status}</div>
                                </div>
                            } else {
                                <div style={{"fontSize": "14px", "marginTop": "6px"}}>{"Status: " + (outcome.register_status or "not checked")}</div>
                            }}
                            {if outcome.alerts_sent > 0 {
                                <div style={{"marginTop": "8px", "fontSize": "13px", "color": "#7c3aed"}}>{f"Network Guardian warned {outcome.alerts_sent} earlier check(s) sharing a contact."}</div>
                            }}
                        </div>
                    </div>

                    {if outcome.advice is not None {
                        <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "16px"}}>
                            <div style={CARD}>
                                <div style={LABEL}>Ask before paying or signing</div>
                                <ul style={{"paddingLeft": "18px", "fontSize": "14px"}}>{[<li key={i} style={{"marginBottom": "4px"}}>{q}</li> for (i, q) in enumerate(outcome.advice.questions_to_ask)]}</ul>
                            </div>
                            <div style={CARD}>
                                <div style={LABEL}>Next steps</div>
                                <ul style={{"paddingLeft": "18px", "fontSize": "14px"}}>{[<li key={i} style={{"marginBottom": "4px"}}>{s}</li> for (i, s) in enumerate(outcome.advice.next_steps)]}</ul>
                            </div>
                        </div>
                    }}

                    <div style={CARD}>
                        <div style={LABEL}>Courtroom</div>
                        <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "12px", "marginTop": "8px", "fontSize": "14px"}}>
                            <div style={{"background": RISK_SOFT, "borderRadius": "10px", "padding": "10px"}}><b>Prosecutor</b><p style={{"margin": "4px 0 0"}}>{outcome.prosecution}</p></div>
                            <div style={{"background": "#e5f5ec", "borderRadius": "10px", "padding": "10px"}}><b>Defender</b><p style={{"margin": "4px 0 0"}}>{outcome.defence}</p></div>
                        </div>
                    </div>

                    {if outcome.advice is not None and outcome.advice.report_draft {
                        <details style={CARD}>
                            <summary style={{"cursor": "pointer", "fontWeight": "700"}}>Draft report to SLBFE (1989)</summary>
                            <pre style={{"whiteSpace": "pre-wrap", "fontFamily": "inherit", "fontSize": "14px", "background": MUTED, "padding": "12px", "borderRadius": "10px"}}>{outcome.advice.report_draft}</pre>
                        </details>
                    }}

                    <details style={CARD}>
                        <summary style={{"cursor": "pointer", "fontWeight": "700"}}>{f"Full agent log ({len(outcome.steps)} steps) and sources"}</summary>
                        <ol style={{"fontSize": "13px", "paddingLeft": "18px"}}>{[<li key={i} style={{"marginBottom": "4px"}}><b>{s.agent}</b>{" · " + s.action + ": " + s.detail}</li> for (i, s) in enumerate(outcome.steps)]}</ol>
                        <ul style={{"fontSize": "13px", "paddingLeft": "18px"}}>{[<li key={i}><b>{src.name}</b>{": " + src.detail}</li> for (i, src) in enumerate(outcome.sources)]}</ul>
                    </details>
                </div>
            }}
        </div>
    </div>;
}
