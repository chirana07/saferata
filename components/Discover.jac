"""Discover: verified job listings with safety badges, search/filter, and a job detail view with worker reports."""

import from jobboard { ListJobs, AddReview, MatchJobs, RespondToReview, RequestCorrection, JobView, JobMatch, PostResult, ReviewView }
import from .Profile { prof }
import from agents { Step }
import from .theme {
    INK, MUTED_INK, PRIMARY, PRIMARY_DEEP, ACCENT, MUTED, BORDER, RISK, RISK_SOFT, CARD, LABEL,
    band_label, band_fg, band_bg
}

def:pub NotBuilt(label: str) -> JsxElement {
    return <span style={{"background": "#f1f3f8", "color": "#8a93a8", "border": "1px dashed #c9cfdc", "borderRadius": "6px", "padding": "1px 7px", "fontSize": "11px", "fontWeight": "600"}}>{label + ": not built yet"}</span>;
}

def risk_rank(band: str) -> int {
    if band == "LOOKS SAFE" {
        return 0;
    }
    if band == "BE CAREFUL" {
        return 1;
    }
    return 2;
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

def money(v: float) -> str {
    return f"Rs. {v:,.0f}" if v > 0 else "not stated";
}

def:pub Discover(onCheck: Callable[[], None], onProfile: Callable[[], None]) -> JsxElement {
    has jobs: list[JobView] = [],
        loading: bool = False,
        query: str = "",
        country: str = "",
        sort: str = "recent",
        open_id: str = "",
        review_author: str = "",
        review_kind: str = "fraud",
        review_text: str = "",
        review_evidence: str = "",
        reviewing: bool = False,
        message: str = "",
        matches: list[JobMatch] = [],
        respond_id: str = "",
        respond_text: str = "",
        correction: str = "",
        last_steps: list[Step] = [];

    async def load -> None {
        loading = True;
        result = root spawn ListJobs();
        jobs = result.reports;
        if prof("saved", "") == "yes" {
            mres = root spawn MatchJobs(occupation=prof("occupation", ""), skills=[x.strip() for x in prof("skills", "").split(",") if x.strip()],
                destinations=[x.strip() for x in prof("destinations", "").split(",") if x.strip()], min_salary_lkr=float(prof("min_salary", "0") or "0"),
                experience_years=int(prof("experience", "0") or "0"), needs_accommodation=prof("accommodation", "yes") == "yes");
            matches = mres.reports;
        }
        loading = False;
    }

    async def respond -> None {
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
        result = root spawn RequestCorrection(job_id=open_id, details=correction);
        if result.reports {
            r: PostResult = result.reports[0];
            message = r.message;
        }
        correction = "";
        await load();
    }

    async def submit_review -> None {
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

    can with entry {
        load();
    }

    q = query.lower();
    shown = [j for j in jobs if (not q or q in (j.title + " " + j.country + " " + j.agency_name + " " + j.description).lower()) and (not country or j.country == country)];
    if sort == "risk" {
        shown = sorted(shown, key=lambda (j: JobView) { risk_rank(j.band); });
    }
    if sort == "match" {
        shown = sorted(shown, key=lambda (j: JobView) { -match_pct(matches, j.id); });
    }
    countries = sorted(list(set([j.country for j in jobs if j.country])));
    agencies = len(set([j.licence_no for j in jobs]));
    high = len([j for j in jobs if j.band == "DANGER"]);
    opened = [j for j in jobs if j.id == open_id];

    if opened {
        jb = opened[0];
        return <div style={{"display": "flex", "flexDirection": "column", "gap": "16px"}}>
            <button onClick={lambda -> None { open_id = ""; message = ""; last_steps = []; }}
                style={{"alignSelf": "flex-start", "background": "transparent", "border": "none", "color": PRIMARY, "fontWeight": "600", "cursor": "pointer", "padding": "0"}}>{"← Back to Discover"}</button>
            <div style={CARD}>
                <div style={{"display": "flex", "justifyContent": "space-between", "gap": "12px", "flexWrap": "wrap"}}>
                    <div>
                        <h2 style={{"margin": "0", "fontSize": "26px"}}>{jb.title + " · " + jb.country}</h2>
                        <div style={{"color": MUTED_INK, "marginTop": "4px"}}>{f"{jb.agency_name} · SLBFE licence {jb.licence_no} (verified live) · posted {jb.posted_at}"}</div>
                    </div>
                    <div style={{"textAlign": "right"}}>
                        <div style={LABEL}>Monthly salary</div>
                        <div style={{"fontSize": "22px", "fontWeight": "800"}}>{jb.salary}</div>
                    </div>
                </div>
            </div>
            <div style={{"display": "grid", "gridTemplateColumns": "minmax(0, 7fr) minmax(0, 5fr)", "gap": "16px", "alignItems": "start"}}>
                <div style={{"display": "flex", "flexDirection": "column", "gap": "16px"}}>
                    <div style={{"background": band_bg(jb.band), "border": "1px solid " + band_fg(jb.band), "borderRadius": "14px", "padding": "18px"}}>
                        <div style={LABEL}>Safety assessment · real agent analysis</div>
                        <div style={{"fontSize": "24px", "fontWeight": "800", "color": band_fg(jb.band)}}>{f"{band_label(jb.band)} · {jb.score}/100"}</div>
                        <p style={{"margin": "6px 0 0"}}>{jb.summary or "No summary."}</p>
                        <div style={{"fontSize": "12px", "color": MUTED_INK, "marginTop": "6px"}}>Separate from any match score. Promotion never changes it.</div>
                    </div>
                    {[<div key={i} style={{"background": "#f5eef8", "border": "1px solid #c4a7e7", "borderRadius": "12px", "padding": "12px", "color": "#4c1d95", "fontWeight": "600"}}>{"Impersonation alert: " + w}</div> for (i, w) in enumerate(jb.warnings)]}
                    <div style={CARD}>
                        <div style={LABEL}>{f"Safety findings ({len(jb.top_flags)})"}</div>
                        {if len(jb.top_flags) == 0 {
                            <p style={{"color": MUTED_INK}}>No supported findings.</p>
                        }}
                        <ul style={{"paddingLeft": "18px"}}>{[<li key={i} style={{"marginBottom": "4px"}}>{f}</li> for (i, f) in enumerate(jb.top_flags)]}</ul>
                    </div>
                    <div style={CARD}>
                        <div style={LABEL}>Full job description</div>
                        <p style={{"margin": "6px 0 0", "whiteSpace": "pre-wrap"}}>{jb.description}</p>
                    </div>
                    <div style={CARD}>
                        <div style={LABEL}>Pay & deductions</div>
                        <table style={{"width": "100%", "fontSize": "14px", "marginTop": "6px", "borderCollapse": "collapse"}}><tbody>
                            <tr><td style={{"color": MUTED_INK, "padding": "3px 0"}}>Basic salary</td><td>{jb.salary + (" (≈ " + money(jb.salary_lkr) + ")" if jb.salary_lkr > 0 else "")}</td></tr>
                            <tr><td style={{"color": MUTED_INK, "padding": "3px 0"}}>Deductions</td><td>{jb.deductions or "none disclosed"}</td></tr>
                            <tr><td style={{"color": MUTED_INK, "padding": "3px 0"}}>Estimated take-home</td><td style={{"fontWeight": "700"}}>{money(jb.take_home_lkr) + " / month"}</td></tr>
                            <tr><td style={{"color": MUTED_INK, "padding": "3px 0"}}>Recruitment fee to you</td><td>{money(jb.worker_fee_lkr) if jb.worker_fee_lkr > 0 else "none stated"}</td></tr>
                            <tr><td style={{"color": MUTED_INK, "padding": "3px 0"}}>Accommodation</td><td>{jb.accommodation or "not stated"}</td></tr>
                            <tr><td style={{"color": MUTED_INK, "padding": "3px 0"}}>Contract</td><td>{((jb.contract_type + " · ") if jb.contract_type else "") + (f"{jb.contract_months} months" if jb.contract_months else "length not stated")}</td></tr>
                            <tr><td style={{"color": MUTED_INK, "padding": "3px 0"}}>Experience</td><td>{f"{jb.experience_years} year(s)" if jb.experience_years else "none required"}</td></tr>
                        </tbody></table>
                        <div style={{"fontSize": "12px", "color": MUTED_INK, "marginTop": "6px"}}>LKR figures use approximate fixed exchange rates.</div>
                        {[<div key={k} style={{"fontSize": "13px", "color": PRIMARY_DEEP, "marginTop": "6px"}}>{"Appeal " + ap}</div> for (k, ap) in enumerate(jb.appeals)]}
                        {[<div key={k} style={{"fontSize": "13px", "color": MUTED_INK, "marginTop": "4px"}}>{"Correction requested " + c}</div> for (k, c) in enumerate(jb.corrections)]}
                    </div>
                    <div style={CARD}>
                        <div style={LABEL}>{f"Moderated worker reports ({len(jb.reviews)})"}</div>
                        {if jb.credible_fraud_reports > 0 {
                            <div style={{"color": RISK, "fontWeight": "700", "marginTop": "6px"}}>{f"{jb.credible_fraud_reports} credible fraud report(s) against the agency"}</div>
                        }}
                        {[
                            <div key={i} style={{"padding": "10px 0", "borderBottom": "1px solid " + MUTED, "fontSize": "14px"}}>
                                <div style={{"display": "flex", "gap": "6px", "flexWrap": "wrap", "alignItems": "center"}}>
                                    <b>{rv.author}</b>
                                    <span style={{"background": RISK_SOFT if rv.kind == "fraud" else "#e5f5ec", "borderRadius": "6px", "padding": "1px 7px", "fontSize": "11px"}}>{rv.kind}</span>
                                    <span style={{"background": ACCENT, "borderRadius": "6px", "padding": "1px 7px", "fontSize": "11px"}}>{f"Review Verifier: {rv.status} · {rv.credibility}/100"}</span>
                                    <span style={{"color": MUTED_INK, "fontSize": "12px"}}>{rv.created_at}</span>
                                </div>
                                <div style={{"marginTop": "4px"}}>{rv.text}</div>
                                {if rv.evidence {
                                    <div style={{"color": MUTED_INK, "fontStyle": "italic"}}>{"Evidence: " + rv.evidence}</div>
                                }}
                                <div style={{"color": MUTED_INK, "fontSize": "12px"}}>{rv.reason}</div>
                                {if rv.agency_response {
                                    <div style={{"marginTop": "6px", "background": ACCENT, "borderRadius": "8px", "padding": "6px 10px", "fontSize": "13px"}}><b>Agency response: </b>{rv.agency_response}</div>
                                }}
                                {if respond_id == rv.id {
                                    <div style={{"display": "flex", "gap": "6px", "marginTop": "6px"}}>
                                        <input placeholder="Agency response" value={respond_text} onChange={lambda (e: ChangeEvent) { respond_text = e.target.value; }}
                                            style={{"flex": "1", "padding": "7px", "borderRadius": "8px", "border": "1px solid " + BORDER}}/>
                                        <button onClick={lambda { respond(); }} style={{"background": PRIMARY, "color": "white", "border": "none", "borderRadius": "8px", "padding": "6px 12px"}}>Publish</button>
                                    </div>
                                } elif not rv.agency_response {
                                    <button onClick={lambda -> None { respond_id = rv.id; }} style={{"marginTop": "6px", "background": "transparent", "border": "none", "color": PRIMARY, "fontSize": "12px", "cursor": "pointer", "padding": "0"}}>Respond as agency</button>
                                }}
                            </div>
                            for (i, rv) in enumerate(jb.reviews)
                        ]}
                    </div>
                </div>
                <div style={{"display": "flex", "flexDirection": "column", "gap": "16px"}}>
                    <div style={CARD}>
                        <div style={LABEL}>{"Who's behind it"}</div>
                        <div style={{"fontWeight": "700", "marginTop": "6px"}}>{jb.agency_name}</div>
                        <div style={{"fontSize": "14px"}}>{f"SLBFE licence {jb.licence_no} · checked on the live register when posted"}</div>
                        <div style={{"fontSize": "14px", "color": MUTED_INK}}>{"Contact given: " + jb.contact_phone}</div>
                    </div>
                    <div style={CARD}>
                        <div style={LABEL}>Report or review this job</div>
                        <input placeholder="Your name (optional)" value={review_author} onChange={lambda (e: ChangeEvent) { review_author = e.target.value; }}
                            style={{"width": "100%", "boxSizing": "border-box", "padding": "8px", "borderRadius": "8px", "border": "1px solid " + BORDER, "marginTop": "8px"}}/>
                        <select value={review_kind} onChange={lambda (e: ChangeEvent) { review_kind = e.target.value; }}
                            style={{"width": "100%", "padding": "8px", "borderRadius": "8px", "border": "1px solid " + BORDER, "marginTop": "8px"}}>
                            <option value="fraud">Report fraud</option>
                            <option value="positive">Positive experience</option>
                            <option value="other">Other</option>
                        </select>
                        <textarea rows={3} placeholder="What happened? Amounts, dates, what was promised. Don't include your NIC or passport number." value={review_text} onChange={lambda (e: ChangeEvent) { review_text = e.target.value; }}
                            style={{"width": "100%", "boxSizing": "border-box", "padding": "8px", "borderRadius": "8px", "border": "1px solid " + BORDER, "marginTop": "8px", "fontFamily": "inherit"}}/>
                        <textarea rows={2} placeholder="Evidence: receipt, bank slip details, chat excerpt" value={review_evidence} onChange={lambda (e: ChangeEvent) { review_evidence = e.target.value; }}
                            style={{"width": "100%", "boxSizing": "border-box", "padding": "8px", "borderRadius": "8px", "border": "1px solid " + BORDER, "marginTop": "8px", "fontFamily": "inherit"}}/>
                        <button disabled={reviewing} onClick={lambda { submit_review(); }}
                            style={{"marginTop": "8px", "width": "100%", "background": PRIMARY, "color": "white", "border": "none", "borderRadius": "10px", "padding": "10px", "fontWeight": "700"}}>
                            {"Review Verifier checking..." if reviewing else "Submit for verification"}
                        </button>
                        {if message {
                            <div style={{"marginTop": "10px", "fontSize": "13px"}}>
                                <b>{message}</b>
                                <ol style={{"paddingLeft": "18px"}}>{[<li key={i}><b>{s.agent}</b>{": " + s.detail}</li> for (i, s) in enumerate(last_steps)]}</ol>
                            </div>
                        }}
                    </div>
                    <div style={CARD}>
                        <div style={LABEL}>Enquire about this job</div>
                        <ul style={{"paddingLeft": "18px", "fontSize": "14px"}}>
                            <li>Can I see the full contract before paying anything?</li>
                            <li>What is the employer's registration number?</li>
                            <li>Which fees will I pay, to whom, and will I get a receipt?</li>
                        </ul>
                    </div>
                    <div style={CARD}>
                        <div style={LABEL}>Why it matches</div>
                        {if match_pct(matches, jb.id) >= 0 {
                            <div style={{"fontSize": "14px"}}>
                                <div style={{"fontSize": "22px", "fontWeight": "800", "color": PRIMARY_DEEP}}>{f"{match_pct(matches, jb.id)}% match"}</div>
                                <ul style={{"paddingLeft": "18px"}}>{[<li key={k}>{r}</li> for (k, r) in enumerate(match_reasons(matches, jb.id))]}</ul>
                                <ul style={{"paddingLeft": "18px", "color": RISK}}>{[<li key={k}>{c}</li> for (k, c) in enumerate(match_cautions(matches, jb.id))]}</ul>
                                <div style={{"fontSize": "12px", "color": MUTED_INK}}>Based on your profile. A high match does not mean a job is safe.</div>
                            </div>
                        } else {
                            <button onClick={lambda -> None { onProfile(); }} style={{"background": ACCENT, "color": PRIMARY_DEEP, "border": "none", "borderRadius": "8px", "padding": "7px 12px", "fontWeight": "600", "marginTop": "6px"}}>Add your profile to see why it matches</button>
                        }}
                    </div>
                    <div style={CARD}>
                        <div style={LABEL}>Request a correction</div>
                        <textarea rows={2} placeholder="What is wrong in this listing?" value={correction} onChange={lambda (e: ChangeEvent) { correction = e.target.value; }}
                            style={{"width": "100%", "boxSizing": "border-box", "padding": "8px", "borderRadius": "8px", "border": "1px solid " + BORDER, "marginTop": "8px", "fontFamily": "inherit"}}/>
                        <button onClick={lambda { request_correction(); }} style={{"marginTop": "6px", "background": MUTED, "border": "1px solid " + BORDER, "borderRadius": "8px", "padding": "6px 12px"}}>Send for moderation</button>
                    </div>
                </div>
            </div>
        </div>;
    }

    return <div style={{"display": "grid", "gridTemplateColumns": "minmax(0, 8fr) minmax(0, 4fr)", "gap": "18px", "alignItems": "start"}}>
        <div style={{"display": "flex", "flexDirection": "column", "gap": "14px"}}>
            <div>
                <h1 style={{"fontSize": "32px", "margin": "0 0 4px", "letterSpacing": "-0.5px"}}>Find work abroad, <span style={{"color": PRIMARY}}>with confidence.</span></h1>
                <p style={{"color": MUTED_INK, "margin": "0"}}>Every listing comes from an agency verified on the live SLBFE register, and every posting is investigated by the agent team.</p>
            </div>
            <div style={{"display": "flex", "gap": "8px", "flexWrap": "wrap"}}>
                <input placeholder="Occupation, destination or keyword, e.g. driver or Qatar" value={query} onChange={lambda (e: ChangeEvent) { query = e.target.value; }}
                    style={{"flex": "1", "minWidth": "220px", "padding": "11px 14px", "borderRadius": "10px", "border": "1px solid " + BORDER, "fontSize": "14px"}}/>
                <select value={country} onChange={lambda (e: ChangeEvent) { country = e.target.value; }}
                    style={{"padding": "10px", "borderRadius": "10px", "border": "1px solid " + BORDER}}>
                    <option value="">Any destination</option>
                    {[<option key={c} value={c}>{c}</option> for c in countries]}
                </select>
                <select value={sort} onChange={lambda (e: ChangeEvent) { sort = e.target.value; }}
                    style={{"padding": "10px", "borderRadius": "10px", "border": "1px solid " + BORDER}}>
                    <option value="recent">Most recent</option>
                    <option value="risk">Lowest risk first</option>
                    <option value="match">Best match</option>
                </select>
            </div>
            {if loading and len(jobs) == 0 {
                <p style={{"color": MUTED_INK}}>Loading listings...</p>
            }}
            {if not loading and len(shown) == 0 {
                <div style={CARD}><p style={{"margin": "0", "color": MUTED_INK}}>No listings yet. Licensed agencies can post from the Agency portal.</p></div>
            }}
            {[
                <div key={j.id} style={CARD}>
                    <div style={{"display": "flex", "justifyContent": "space-between", "gap": "12px", "flexWrap": "wrap"}}>
                        <div>
                            <div style={{"fontSize": "18px", "fontWeight": "700"}}>{j.title + " · " + j.country}</div>
                            <div style={{"color": MUTED_INK, "fontSize": "13px", "marginTop": "2px"}}>{f"{j.agency_name} · posted {j.posted_at}"}</div>
                        </div>
                        <div style={{"fontWeight": "800"}}>{j.salary}</div>
                    </div>
                    <div style={{"display": "flex", "gap": "8px", "flexWrap": "wrap", "marginTop": "10px", "alignItems": "center"}}>
                        <span style={{"background": band_bg(j.band), "color": band_fg(j.band), "borderRadius": "999px", "padding": "3px 10px", "fontSize": "12px", "fontWeight": "700"}}>{f"Safety: {band_label(j.band)} · {j.score}"}</span>
                        <span style={{"background": ACCENT, "color": PRIMARY_DEEP, "borderRadius": "999px", "padding": "3px 10px", "fontSize": "12px", "fontWeight": "600"}}>{f"Licence {j.licence_no}: verified live"}</span>
                        {if j.credible_fraud_reports > 0 {
                            <span style={{"background": RISK_SOFT, "color": RISK, "borderRadius": "999px", "padding": "3px 10px", "fontSize": "12px", "fontWeight": "700"}}>{f"{j.credible_fraud_reports} credible fraud report(s)"}</span>
                        }}
                        {if len(j.warnings) > 0 {
                            <span style={{"background": "#f5eef8", "color": "#6d28d9", "borderRadius": "999px", "padding": "3px 10px", "fontSize": "12px", "fontWeight": "700"}}>Impersonators reported</span>
                        }}
                        {if match_pct(matches, j.id) >= 0 {
                            <span style={{"background": "#eef2ff", "color": PRIMARY_DEEP, "borderRadius": "999px", "padding": "3px 10px", "fontSize": "12px", "fontWeight": "700"}}>{f"Match: {match_pct(matches, j.id)}%"}</span>
                        }}
                        {if j.salary_lkr > 0 {
                            <span style={{"color": MUTED_INK, "fontSize": "12px"}}>{"≈ " + money(j.salary_lkr) + " / month"}</span>
                        }}
                        <button onClick={lambda -> None { open_id = j.id; message = ""; last_steps = []; }}
                            style={{"marginLeft": "auto", "background": PRIMARY, "color": "white", "border": "none", "borderRadius": "8px", "padding": "7px 14px", "fontWeight": "600", "cursor": "pointer"}}>Open</button>
                    </div>
                </div>
                for j in shown
            ]}
        </div>
        <div style={{"display": "flex", "flexDirection": "column", "gap": "14px"}}>
            <div style={CARD}>
                <div style={LABEL}>Trust intelligence</div>
                <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr 1fr", "gap": "8px", "marginTop": "10px", "textAlign": "center"}}>
                    <div><div style={{"fontSize": "22px", "fontWeight": "800"}}>{str(len(jobs))}</div><div style={{"fontSize": "12px", "color": MUTED_INK}}>Listings</div></div>
                    <div><div style={{"fontSize": "22px", "fontWeight": "800"}}>{str(agencies)}</div><div style={{"fontSize": "12px", "color": MUTED_INK}}>Agencies</div></div>
                    <div><div style={{"fontSize": "22px", "fontWeight": "800", "color": RISK}}>{str(high)}</div><div style={{"fontSize": "12px", "color": MUTED_INK}}>High risk</div></div>
                </div>
            </div>
            <div style={{"background": PRIMARY_DEEP, "color": "white", "borderRadius": "14px", "padding": "18px"}}>
                <div style={{"fontWeight": "800", "fontSize": "17px"}}>Got an offer on WhatsApp or Facebook?</div>
                <p style={{"opacity": "0.85", "fontSize": "14px"}}>Most scams never appear on a job board. Paste it and let the agents check it.</p>
                <button onClick={lambda -> None { onCheck(); }}
                    style={{"background": "white", "color": PRIMARY_DEEP, "border": "none", "borderRadius": "8px", "padding": "9px 14px", "fontWeight": "700", "cursor": "pointer"}}>Check an offer you received</button>
            </div>
            <div style={CARD}>
                <div style={LABEL}>Your profile</div>
                <p style={{"fontSize": "14px", "color": MUTED_INK}}>{("Matching for " + (prof("occupation", "") or "your profile") + ". Listings show a match % and the reasons.") if prof("saved", "") == "yes" else "Add your occupation, skills and destinations to see a match % on every listing."}</p>
                <button onClick={lambda -> None { onProfile(); }} style={{"background": ACCENT, "color": PRIMARY_DEEP, "border": "none", "borderRadius": "8px", "padding": "7px 12px", "fontWeight": "600"}}>{"Edit profile" if prof("saved", "") == "yes" else "Add work preferences"}</button>
            </div>
        </div>
    </div>;
}
