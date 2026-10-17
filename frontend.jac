"""SafeRata - client UI: paste an offer, watch the agent team investigate, read the verdict."""

import from agents { Investigate, CaseReport, Step }
import from rules { RedFlag }
import from .components.Board { JobBoard }

glob SAMPLE_TRAFFICKING = "URGENT HIRING!!! IT / Data Entry jobs in THAILAND\nSalary USD 1500 per month + free accommodation + food\nNo experience needed, basic English and typing only.\nAir ticket FREE. Travel on tourist visa, company will change to work visa after arrival.\nOnly 5 seats left - pay Rs. 150,000 processing fee to confirm your seat.\nDeposit to Commercial Bank account 8012345678 (K. Perera). Send slip on WhatsApp +94 76 555 1234";

glob SAMPLE_IMPERSONATION = "A T C GLOBAL HOLDINGS (PVT) LTD - Licence No 3500\nQatar - House Driver vacancies. Salary QAR 1800. Employment visa.\nRegistration fee Rs. 75,000 must be paid before interview to reserve your place.\nContact our recruitment officer on WhatsApp 0789 123 456";

glob SAMPLE_GENUINE = "A T C GLOBAL HOLDINGS (PVT) LTD (SLBFE Licence No 3500)\nVacancy: Light vehicle driver - Qatar. Employment visa sponsored by employer.\nSalary QAR 2000 + accommodation. 2-year contract provided before departure.\nAll payments only at our Nugegoda office with official receipt, after you sign the contract.\nCall 0112818268 or email info@atcs.lk";

def band_color(band: str) -> str {
    if band == "DANGER" {
        return "#c0392b";
    }
    if band == "BE CAREFUL" {
        return "#d68910";
    }
    return "#1e8449";
}

def agent_color(agent: str) -> str {
    palette: dict[str, str] = {
        "Supervisor": "#5b2c6f",
        "Extractor": "#1f618d",
        "Lead Investigator": "#117864",
        "Prosecutor": "#922b21",
        "Defender": "#1e8449",
        "Judge": "#7d6608",
        "Critic": "#6e2c00",
        "Advisor": "#2e4053",
        "Network Guardian": "#512e5f"
    };
    return palette.get(agent, "#34495e");
}

def:pub app -> JsxElement {
    has text: str = "",
        busy: bool = False,
        outcome: CaseReport | None = None,
        answers: list[str] = [],
        tab: str = "check",
        error: str = "";

    async def investigate -> None;
    async def submit_answers -> None;

    <div style={{"maxWidth": "980px", "margin": "0 auto", "padding": "24px 16px", "fontFamily": "system-ui, -apple-system, Segoe UI, sans-serif", "color": "#1b2631"}}>
        <header style={{"display": "flex", "alignItems": "baseline", "gap": "12px", "flexWrap": "wrap"}}>
            <h1 style={{"margin": "0", "fontSize": "30px"}}>SafeRata</h1>
            <span style={{"color": "#566573"}}>Check a foreign job offer before you pay. A team of AI agents investigates it against the official SLBFE register.</span>
        </header>
        <nav style={{"display": "flex", "gap": "8px", "marginTop": "14px"}}>
            <button onClick={lambda -> None { tab = "check"; }}
                style={{"padding": "8px 14px", "borderRadius": "999px", "border": "1px solid #1b4f72", "background": "#1b4f72" if tab == "check" else "white", "color": "white" if tab == "check" else "#1b4f72", "fontWeight": "600"}}>Check an offer</button>
            <button onClick={lambda -> None { tab = "board"; }}
                style={{"padding": "8px 14px", "borderRadius": "999px", "border": "1px solid #1b4f72", "background": "#1b4f72" if tab == "board" else "white", "color": "white" if tab == "board" else "#1b4f72", "fontWeight": "600"}}>Verified job board</button>
        </nav>
        {if tab == "board" {
            <section style={{"marginTop": "16px"}}><JobBoard/></section>
        }}

        {if tab == "check" {
        <section style={{"marginTop": "20px", "background": "#f8f9f9", "border": "1px solid #d5d8dc", "borderRadius": "12px", "padding": "16px"}}>
            <label style={{"fontWeight": "600"}}>Paste the job ad, WhatsApp message or contract</label>
            <textarea id="offer" value={text} rows={7}
                onChange={lambda (e: ChangeEvent) { text = e.target.value; }}
                placeholder="e.g. URGENT HIRING - Qatar house driver, salary..."
                style={{"width": "100%", "boxSizing": "border-box", "marginTop": "8px", "padding": "10px", "borderRadius": "8px", "border": "1px solid #aab7b8", "fontSize": "14px", "fontFamily": "inherit"}}/>
            <div style={{"display": "flex", "gap": "8px", "flexWrap": "wrap", "marginTop": "10px", "alignItems": "center"}}>
                <button id="investigate" disabled={busy} onClick={lambda { investigate(); }}
                    style={{"background": "#1b4f72", "color": "white", "border": "none", "borderRadius": "8px", "padding": "10px 18px", "fontWeight": "600", "cursor": "pointer"}}>
                    {"Agents investigating..." if busy else "Investigate offer"}
                </button>
                <span style={{"color": "#566573", "fontSize": "13px"}}>Try a sample:</span>
                <button onClick={lambda -> None { text = SAMPLE_TRAFFICKING; }}>Thailand IT job</button>
                <button onClick={lambda -> None { text = SAMPLE_IMPERSONATION; }}>Agency impersonation</button>
                <button onClick={lambda -> None { text = SAMPLE_GENUINE; }}>Genuine offer</button>
            </div>
            {if busy {
                <p style={{"color": "#1b4f72"}}>Extractor, Lead Investigator, specialists, Prosecutor, Defender, Judge and Advisor are working. This takes 30-90 seconds.</p>
            }}
            {if error {
                <p style={{"color": "#c0392b"}}>{error}</p>
            }}
        </section>
        }}

        {if tab == "check" and outcome is not None and outcome.status == "needs_input" {
            <section id="questions" style={{"marginTop": "20px", "border": "2px solid #d68910", "borderRadius": "12px", "padding": "16px"}}>
                <h3 style={{"marginTop": "0"}}>The investigator needs a few answers</h3>
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
                            style={{"width": "100%", "boxSizing": "border-box", "padding": "8px", "borderRadius": "6px", "border": "1px solid #aab7b8"}}/>
                    </div>
                    for (i, q) in enumerate(outcome.questions)
                ]}
                <button disabled={busy} onClick={lambda { submit_answers(); }}
                    style={{"background": "#d68910", "color": "white", "border": "none", "borderRadius": "8px", "padding": "10px 18px", "fontWeight": "600"}}>
                    {"Continuing..." if busy else "Continue investigation"}
                </button>
            </section>
        }}

        {if tab == "check" and outcome is not None and outcome.status == "done" {
            <section id="result" style={{"marginTop": "20px"}}>
                <div style={{"background": band_color(outcome.band), "color": "white", "borderRadius": "12px", "padding": "16px 20px", "display": "flex", "justifyContent": "space-between", "alignItems": "center", "flexWrap": "wrap", "gap": "8px"}}>
                    <div>
                        <div style={{"fontSize": "26px", "fontWeight": "800"}} id="band">{outcome.band}</div>
                        <div style={{"opacity": "0.9"}}>{outcome.judge}</div>
                    </div>
                    <div style={{"textAlign": "right"}}>
                        <div style={{"fontSize": "34px", "fontWeight": "800"}}>{f"{outcome.score}/100"}</div>
                        <div style={{"fontSize": "12px", "opacity": "0.9"}}>{f"official rules & register {outcome.hard_points} + agent judgement {outcome.soft_points} (max 20)"}</div>
                    </div>
                </div>

                {if outcome.agency is not None {
                    <div style={{"marginTop": "12px", "padding": "12px", "border": "1px solid #d5d8dc", "borderRadius": "10px", "background": "#fdfefe"}}>
                        <b>SLBFE register: </b>{f"{outcome.register_status} - {outcome.agency.name} (licence {outcome.agency.licence_no}, valid until {outcome.agency.valid_upto}). Registered phones: {', '.join(outcome.agency.phones)}"}
                    </div>
                } elif outcome.register_status {
                    <div style={{"marginTop": "12px", "padding": "12px", "border": "1px solid #d5d8dc", "borderRadius": "10px"}}>
                        <b>SLBFE register: </b>{outcome.register_status}
                    </div>
                }}

                {if outcome.alerts_sent > 0 {
                    <div style={{"marginTop": "12px", "padding": "12px", "borderRadius": "10px", "background": "#f5eef8"}}>
                        {f"Network Guardian warned {outcome.alerts_sent} earlier check(s) that share a contact with this offer."}
                    </div>
                }}

                <h2>{f"Red flags ({len(outcome.flags)})"}</h2>
                {[
                    <div key={i} style={{"borderLeft": "5px solid " + band_color("DANGER" if f.points >= 25 else "BE CAREFUL"), "background": "#fbfcfc", "padding": "10px 14px", "marginBottom": "10px", "borderRadius": "6px"}}>
                        <div style={{"display": "flex", "justifyContent": "space-between", "gap": "8px", "flexWrap": "wrap"}}>
                            <b>{f.title}</b>
                            <span style={{"fontSize": "12px", "color": "#566573"}}>{f"+{f.points} pts | {f.source} | {f.agent}"}</span>
                        </div>
                        <div style={{"fontStyle": "italic", "color": "#7b241c", "margin": "4px 0"}}>{"\"" + f.evidence + "\""}</div>
                        <div>{f.explanation}</div>
                    </div>
                    for (i, f) in enumerate(outcome.flags)
                ]}
                {if len(outcome.removed) > 0 {
                    <p style={{"fontSize": "13px", "color": "#6e2c00"}}>{f"Critic removed {len(outcome.removed)} unsupported claim(s): " + "; ".join(outcome.removed)}</p>
                }}

                <h2>Courtroom</h2>
                <div style={{"display": "grid", "gridTemplateColumns": "repeat(auto-fit, minmax(260px, 1fr))", "gap": "12px"}}>
                    <div style={{"background": "#fdedec", "borderRadius": "10px", "padding": "12px"}}><b>Prosecutor</b><p>{outcome.prosecution}</p></div>
                    <div style={{"background": "#e9f7ef", "borderRadius": "10px", "padding": "12px"}}><b>Defender</b><p>{outcome.defence}</p></div>
                </div>

                {if outcome.advice is not None {
                    <div style={{"display": "grid", "gridTemplateColumns": "repeat(auto-fit, minmax(260px, 1fr))", "gap": "12px", "marginTop": "12px"}}>
                        <div style={{"border": "1px solid #d5d8dc", "borderRadius": "10px", "padding": "12px"}}>
                            <b>Ask the agency before paying</b>
                            <ul>{[<li key={i}>{q}</li> for (i, q) in enumerate(outcome.advice.questions_to_ask)]}</ul>
                        </div>
                        <div style={{"border": "1px solid #d5d8dc", "borderRadius": "10px", "padding": "12px"}}>
                            <b>What to do next</b>
                            <ul>{[<li key={i}>{s}</li> for (i, s) in enumerate(outcome.advice.next_steps)]}</ul>
                        </div>
                    </div>
                }}
                {if outcome.advice is not None and outcome.advice.report_draft {
                    <details style={{"marginTop": "12px"}}>
                        <summary style={{"cursor": "pointer", "fontWeight": "600"}}>Ready-made outcome to SLBFE (1989)</summary>
                        <pre style={{"whiteSpace": "pre-wrap", "background": "#f4f6f7", "padding": "12px", "borderRadius": "8px"}}>{outcome.advice.report_draft}</pre>
                    </details>
                }}

                <h2>Agent activity</h2>
                <ol id="steps" style={{"paddingLeft": "20px"}}>
                    {[
                        <li key={i} style={{"marginBottom": "6px"}}>
                            <span style={{"background": agent_color(s.agent), "color": "white", "borderRadius": "4px", "padding": "1px 6px", "fontSize": "12px", "marginRight": "6px"}}>{s.agent}</span>
                            <code style={{"fontSize": "12px"}}>{s.action}</code> {s.detail}
                        </li>
                        for (i, s) in enumerate(outcome.steps)
                    ]}
                </ol>

                <h2>Sources</h2>
                <ul>{[<li key={i}><b>{src.name}</b>{": " + src.detail + " "}<a href={src.url} target="_blank">{src.url}</a></li> for (i, src) in enumerate(outcome.sources)]}</ul>
            </section>
        }}
    </div>
}
