"""Agency portal: post a listing -> live SLBFE licence gate -> full agent analysis before it appears on Discover."""

import from jobboard { PostJob, AppealFinding, PostResult, JobView }
import from agents { Step }
import from .theme { INK, MUTED_INK, PRIMARY, PRIMARY_DEEP, ACCENT, MUTED, BORDER, RISK, CARD, LABEL, band_label, band_fg, band_bg }
import from .Discover { NotBuilt }

def has_any(text: str, words: list[str]) -> bool {
    low = text.lower();
    return any([w in low for w in words]);
}

def:pub AgencyPortal(onPosted: Callable[[], None]) -> JsxElement {
    has title: str = "",
        country: str = "",
        salary: str = "",
        description: str = "",
        licence_no: str = "",
        contact_phone: str = "",
        occupation: str = "",
        experience_years: str = "0",
        contract_type: str = "Fixed term",
        contract_months: str = "24",
        accommodation: str = "",
        deductions: str = "",
        monthly_deductions: str = "0",
        worker_fee_lkr: str = "0",
        appeal_job: str = "",
        appeal_finding: str = "",
        appeal_text: str = "",
        appeal_evidence: str = "",
        appealing: bool = False,
        posting: bool = False,
        message: str = "",
        last_steps: list[Step] = [],
        mine: list[JobView] = [];

    def fill_sample {
        title = "Factory Machine Operator";
        country = "Malaysia";
        salary = "MYR 1,700 + overtime";
        description = "Employment visa. Free accommodation. 2-year contract. Pay Rs. 200,000 service charge to our officer's account before medical. Passport will be kept by the company for safety.";
        licence_no = "3500";
        contact_phone = "0765551234";
        occupation = "Manufacturing";
        experience_years = "0";
        accommodation = "Free shared hostel";
        deductions = "Levy MYR 60, food MYR 150";
        monthly_deductions = "210";
        worker_fee_lkr = "200000";
    }

    async def appeal -> None {
        appealing = True;
        result = root spawn AppealFinding(job_id=appeal_job, finding=appeal_finding, explanation=appeal_text, evidence=appeal_evidence);
        if result.reports {
            r: PostResult = result.reports[0];
            message = r.message;
            last_steps = r.steps;
            if r.job is not None {
                updated: JobView = r.job;
                mine = [updated if x.id == updated.id else x for x in mine];
            }
        }
        appeal_job = "";
        appeal_text = "";
        appeal_evidence = "";
        appealing = False;
    }

    async def submit -> None {
        posting = True;
        message = "Gatekeeper is checking the licence on the live SLBFE register, then the agent team analyses the listing...";
        last_steps = [];
        result = root spawn PostJob(title=title, country=country, salary=salary, description=description, licence_no=licence_no, contact_phone=contact_phone,
            occupation=occupation, experience_years=int(experience_years or "0"), contract_type=contract_type, contract_months=int(contract_months or "0"),
            accommodation=accommodation, deductions=deductions, monthly_deductions=float(monthly_deductions or "0"), worker_fee_lkr=float(worker_fee_lkr or "0"));
        if result.reports {
            r: PostResult = result.reports[0];
            message = r.message;
            last_steps = r.steps;
            if r.ok and r.job is not None {
                mine = [r.job] + mine;
                onPosted();
            }
        }
        posting = False;
    }

    checks: list[list[str]] = [
        ["Role and destination", "yes" if title and country else ""],
        ["Basic salary stated", "yes" if salary else ""],
        ["Employment visa (not tourist)", "yes" if has_any(description, ["employment visa", "work visa", "work permit"]) and not has_any(description, ["tourist visa", "visit visa"]) else ""],
        ["Contract duration", "yes" if has_any(description, ["contract", "year"]) else ""],
        ["Accommodation disclosed", "yes" if accommodation or has_any(description, ["accommodation", "housing"]) else ""],
        ["Deductions disclosed", "yes" if deductions else ""],
        ["Worker fee disclosed", "yes" if worker_fee_lkr != "" else ""]
    ];
    done = len([c for c in checks if c[1]]);
    inp = {"width": "100%", "boxSizing": "border-box", "padding": "9px", "borderRadius": "8px", "border": "1px solid " + BORDER, "marginTop": "4px", "fontFamily": "inherit"};

    return <div style={{"display": "grid", "gridTemplateColumns": "minmax(0, 7fr) minmax(0, 5fr)", "gap": "18px", "alignItems": "start"}}>
        <div style={{"display": "flex", "flexDirection": "column", "gap": "16px"}}>
            <div>
                <h1 style={{"fontSize": "30px", "margin": "0 0 4px"}}>Agency portal</h1>
                <p style={{"color": MUTED_INK, "margin": "0"}}>Only agencies on the live SLBFE register can publish. Every listing is investigated by the agent team before workers see it.</p>
            </div>
            <div style={CARD}>
                <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
                    <div style={LABEL}>New listing</div>
                    <button onClick={lambda -> None { fill_sample(); }} style={{"background": MUTED, "border": "1px solid " + BORDER, "borderRadius": "999px", "padding": "4px 10px", "fontSize": "12px"}}>Fill sample</button>
                </div>
                <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "10px", "marginTop": "8px"}}>
                    <label style={{"fontSize": "13px"}}>Role<input value={title} onChange={lambda (e: ChangeEvent) { title = e.target.value; }} style={inp}/></label>
                    <label style={{"fontSize": "13px"}}>Destination country<input value={country} onChange={lambda (e: ChangeEvent) { country = e.target.value; }} style={inp}/></label>
                    <label style={{"fontSize": "13px"}}>Basic salary (with currency)<input value={salary} onChange={lambda (e: ChangeEvent) { salary = e.target.value; }} style={inp}/></label>
                    <label style={{"fontSize": "13px"}}>SLBFE licence number<input value={licence_no} onChange={lambda (e: ChangeEvent) { licence_no = e.target.value; }} style={inp}/></label>
                    <label style={{"fontSize": "13px"}}>Contact phone<input value={contact_phone} onChange={lambda (e: ChangeEvent) { contact_phone = e.target.value; }} style={inp}/></label>
                    <label style={{"fontSize": "13px"}}>Occupation group<input value={occupation} onChange={lambda (e: ChangeEvent) { occupation = e.target.value; }} style={inp}/></label>
                    <label style={{"fontSize": "13px"}}>Experience required (years)<input value={experience_years} onChange={lambda (e: ChangeEvent) { experience_years = e.target.value; }} style={inp}/></label>
                    <label style={{"fontSize": "13px"}}>Contract type
                        <select value={contract_type} onChange={lambda (e: ChangeEvent) { contract_type = e.target.value; }} style={inp}>
                            <option value="Fixed term">Fixed term</option><option value="Renewable">Renewable</option><option value="Seasonal">Seasonal</option>
                        </select>
                    </label>
                    <label style={{"fontSize": "13px"}}>Contract length (months)<input value={contract_months} onChange={lambda (e: ChangeEvent) { contract_months = e.target.value; }} style={inp}/></label>
                    <label style={{"fontSize": "13px"}}>Accommodation<input value={accommodation} onChange={lambda (e: ChangeEvent) { accommodation = e.target.value; }} style={inp}/></label>
                    <label style={{"fontSize": "13px"}}>Deductions (what for)<input value={deductions} onChange={lambda (e: ChangeEvent) { deductions = e.target.value; }} style={inp}/></label>
                    <label style={{"fontSize": "13px"}}>Monthly deductions (salary currency)<input value={monthly_deductions} onChange={lambda (e: ChangeEvent) { monthly_deductions = e.target.value; }} style={inp}/></label>
                    <label style={{"fontSize": "13px"}}>Recruitment fee charged to the worker (LKR)<input value={worker_fee_lkr} onChange={lambda (e: ChangeEvent) { worker_fee_lkr = e.target.value; }} style={inp}/></label>
                </div>
                <label style={{"fontSize": "13px", "display": "block", "marginTop": "10px"}}>Visa, contract, housing and fees
                    <textarea rows={4} value={description} onChange={lambda (e: ChangeEvent) { description = e.target.value; }} style={inp}/>
                </label>
                <div style={{"marginTop": "10px"}}><NotBuilt label="Document upload (demand letter, contract)"/></div>
                <button disabled={posting} onClick={lambda { submit(); }}
                    style={{"marginTop": "12px", "width": "100%", "background": PRIMARY, "color": "white", "border": "none", "borderRadius": "10px", "padding": "12px", "fontWeight": "700"}}>
                    {"Verifying licence and analysing..." if posting else "Submit for verification"}
                </button>
                {if message {
                    <div style={{"marginTop": "12px", "fontSize": "13px", "background": ACCENT, "borderRadius": "10px", "padding": "10px"}}>
                        <b>{message}</b>
                        <ol style={{"paddingLeft": "18px", "marginBottom": "0"}}>{[<li key={i}><b>{s.agent}</b>{" · " + s.action + ": " + s.detail[:140]}</li> for (i, s) in enumerate(last_steps)]}</ol>
                    </div>
                }}
            </div>
        </div>
        <div style={{"display": "flex", "flexDirection": "column", "gap": "16px"}}>
            <div style={CARD}>
                <div style={LABEL}>{f"Pre-publication checklist ({done}/{len(checks)})"}</div>
                {[
                    <div key={i} style={{"display": "flex", "gap": "8px", "padding": "6px 0", "fontSize": "14px"}}>
                        <span style={{"color": "#1d8a55" if c[1] else "#b7bfd0", "fontWeight": "800"}}>{"✓" if c[1] else "○"}</span>{c[0]}
                    </div>
                    for (i, c) in enumerate(checks)
                ]}
                <div style={{"fontSize": "12px", "color": MUTED_INK, "marginTop": "6px"}}>Computed in the browser from what you typed. The agent team runs the real analysis on submit.</div>
            </div>
            <div style={CARD}>
                <div style={LABEL}>Your listings (this session)</div>
                {if len(mine) == 0 {
                    <p style={{"color": MUTED_INK, "fontSize": "14px"}}>No listings submitted yet.</p>
                }}
                {[
                    <div key={j.id} style={{"padding": "8px 0", "borderBottom": "1px solid " + MUTED}}>
                        <div style={{"display": "flex", "justifyContent": "space-between", "gap": "8px"}}>
                            <b>{j.title + " · " + j.country}</b>
                            <span style={{"background": band_bg(j.band), "color": band_fg(j.band), "borderRadius": "999px", "padding": "2px 9px", "fontSize": "12px", "fontWeight": "700"}}>{f"{band_label(j.band)} {j.score}"}</span>
                        </div>
                        <div style={{"fontSize": "12px", "color": MUTED_INK}}>{"; ".join(j.top_flags) or "No findings"}</div>
                        {[<div key={k} style={{"fontSize": "12px", "color": PRIMARY_DEEP, "marginTop": "4px"}}>{"Appeal " + ap}</div> for (k, ap) in enumerate(j.appeals)]}
                        {if len(j.appealable) > 0 and appeal_job != j.id {
                            <button onClick={lambda -> None { appeal_job = j.id; appeal_finding = j.appealable[0]; }}
                                style={{"marginTop": "6px", "background": MUTED, "border": "1px solid " + BORDER, "borderRadius": "8px", "padding": "4px 10px", "fontSize": "12px"}}>Dispute a finding</button>
                        }}
                        {if appeal_job == j.id {
                            <div style={{"marginTop": "8px", "display": "flex", "flexDirection": "column", "gap": "6px"}}>
                                <select value={appeal_finding} onChange={lambda (e: ChangeEvent) { appeal_finding = e.target.value; }} style={inp}>
                                    {[<option key={k} value={f}>{f}</option> for (k, f) in enumerate(j.appealable)]}
                                </select>
                                <textarea rows={2} placeholder="Explain why the finding is wrong or what you changed" value={appeal_text} onChange={lambda (e: ChangeEvent) { appeal_text = e.target.value; }} style={inp}/>
                                <input placeholder="Evidence (receipt number, contract clause...)" value={appeal_evidence} onChange={lambda (e: ChangeEvent) { appeal_evidence = e.target.value; }} style={inp}/>
                                <button disabled={appealing} onClick={lambda { appeal(); }}
                                    style={{"background": PRIMARY, "color": "white", "border": "none", "borderRadius": "8px", "padding": "7px", "fontWeight": "700"}}>{"Appeal Reviewer deciding..." if appealing else "Send appeal"}</button>
                            </div>
                        }}
                    </div>
                    for j in mine
                ]}
                <div style={{"fontSize": "12px", "color": MUTED_INK, "marginTop": "8px"}}>Only agent-judgement findings can be appealed. Official register and rule findings are resolved with the SLBFE.</div>
            </div>
        </div>
    </div>;
}
