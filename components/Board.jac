"""Job board UI: licensed agencies post jobs (auto-analysed), workers add evidence-backed reviews."""

import from jobboard { PostJob, ListJobs, AddReview, JobView, PostResult, ReviewView }
import from agents { Step }

def chip_color(band: str) -> str {
    if band == "DANGER" {
        return "#c0392b";
    }
    if band == "BE CAREFUL" {
        return "#d68910";
    }
    return "#1e8449";
}

def:pub JobBoard -> JsxElement {
    has jobs: list[JobView] = [],
        loading: bool = False,
        posting: bool = False,
        show_form: bool = False,
        message: str = "",
        last_steps: list[Step] = [],
        title: str = "",
        country: str = "",
        salary: str = "",
        description: str = "",
        licence_no: str = "",
        contact_phone: str = "",
        review_job: str = "",
        review_author: str = "",
        review_kind: str = "fraud",
        review_text: str = "",
        review_evidence: str = "",
        reviewing: bool = False;

    async def load -> None {
        loading = True;
        result = root spawn ListJobs();
        jobs = result.reports;
        loading = False;
    }

    async def post -> None {
        posting = True;
        message = "Gatekeeper is verifying the licence and the agent team is analysing the posting...";
        result = root spawn PostJob(title=title, country=country, salary=salary, description=description, licence_no=licence_no, contact_phone=contact_phone);
        if result.reports {
            r: PostResult = result.reports[0];
            message = r.message;
            last_steps = r.steps;
            if r.ok {
                show_form = False;
                title = "";
                description = "";
                await load();
            }
        }
        posting = False;
    }

    async def submit_review -> None {
        reviewing = True;
        result = root spawn AddReview(job_id=review_job, author=review_author, kind=review_kind, text=review_text, evidence=review_evidence);
        if result.reports {
            r: PostResult = result.reports[0];
            message = r.message;
            last_steps = r.steps;
        }
        review_text = "";
        review_evidence = "";
        review_job = "";
        reviewing = False;
        await load();
    }

    def fill_sample {
        title = "Factory Machine Operator";
        country = "Malaysia";
        salary = "MYR 1,700 + overtime";
        description = "Employment visa. Free accommodation. Pay Rs. 200,000 service charge to our officer's account before medical. Passport will be kept by the company for safety.";
        licence_no = "3500";
        contact_phone = "0765551234";
    }

    can with entry {
        load();
    }

    return <div>
        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "flexWrap": "wrap", "gap": "8px"}}>
            <p style={{"color": "#566573", "margin": "0"}}>Only agencies on the live SLBFE register can post. Every posting is investigated by the agent team, and workers can report fraud with evidence.</p>
            <button onClick={lambda -> None { show_form = not show_form; }}
                style={{"background": "#1b4f72", "color": "white", "border": "none", "borderRadius": "8px", "padding": "8px 14px", "fontWeight": "600"}}>
                {"Close" if show_form else "Post a job (agencies)"}
            </button>
        </div>

        {if show_form {
            <div style={{"marginTop": "12px", "background": "#f8f9f9", "border": "1px solid #d5d8dc", "borderRadius": "12px", "padding": "14px", "display": "grid", "gridTemplateColumns": "repeat(auto-fit, minmax(220px, 1fr))", "gap": "8px"}}>
                <input placeholder="Job title" value={title} onChange={lambda (e: ChangeEvent) { title = e.target.value; }}/>
                <input placeholder="Country" value={country} onChange={lambda (e: ChangeEvent) { country = e.target.value; }}/>
                <input placeholder="Salary" value={salary} onChange={lambda (e: ChangeEvent) { salary = e.target.value; }}/>
                <input placeholder="SLBFE licence no." value={licence_no} onChange={lambda (e: ChangeEvent) { licence_no = e.target.value; }}/>
                <input placeholder="Contact phone" value={contact_phone} onChange={lambda (e: ChangeEvent) { contact_phone = e.target.value; }}/>
                <textarea placeholder="Job description, visa, fees, conditions" rows={3} value={description}
                    onChange={lambda (e: ChangeEvent) { description = e.target.value; }} style={{"gridColumn": "1 / -1"}}/>
                <div style={{"gridColumn": "1 / -1", "display": "flex", "gap": "8px"}}>
                    <button disabled={posting} onClick={lambda { post(); }}
                        style={{"background": "#117864", "color": "white", "border": "none", "borderRadius": "8px", "padding": "8px 14px", "fontWeight": "600"}}>
                        {"Verifying and analysing..." if posting else "Submit posting"}
                    </button>
                    <button onClick={lambda -> None { fill_sample(); }}>Fill sample</button>
                </div>
            </div>
        }}

        {if message {
            <div style={{"marginTop": "12px", "padding": "10px", "background": "#eaf2f8", "borderRadius": "8px"}}>
                <b>{message}</b>
                {if len(last_steps) > 0 {
                    <ol style={{"fontSize": "13px", "marginBottom": "0"}}>{[<li key={i}><b>{s.agent}</b>{" " + s.action + ": " + s.detail}</li> for (i, s) in enumerate(last_steps)]}</ol>
                }}
            </div>
        }}

        {if loading and len(jobs) == 0 {
            <p>Loading jobs...</p>
        }}
        {if not loading and len(jobs) == 0 {
            <p style={{"color": "#566573"}}>No jobs posted yet.</p>
        }}

        {[
            <div key={j.id} style={{"marginTop": "14px", "border": "1px solid #d5d8dc", "borderRadius": "12px", "padding": "14px"}}>
                <div style={{"display": "flex", "justifyContent": "space-between", "gap": "8px", "flexWrap": "wrap"}}>
                    <div>
                        <div style={{"fontSize": "18px", "fontWeight": "700"}}>{j.title + " - " + j.country}</div>
                        <div style={{"color": "#566573", "fontSize": "13px"}}>{f"{j.agency_name} | SLBFE licence {j.licence_no} (verified live) | {j.salary} | posted {j.posted_at}"}</div>
                    </div>
                    <span style={{"background": chip_color(j.band), "color": "white", "borderRadius": "999px", "padding": "4px 12px", "fontWeight": "700", "height": "fit-content"}}>{f"{j.band} {j.score}/100"}</span>
                </div>
                <p style={{"marginBottom": "6px"}}>{j.description}</p>
                {if len(j.top_flags) > 0 {
                    <div style={{"fontSize": "13px", "color": "#7b241c"}}>{"Agent findings: " + "; ".join(j.top_flags)}</div>
                }}
                {[<div key={i} style={{"marginTop": "6px", "padding": "6px 10px", "background": "#f5eef8", "borderRadius": "6px", "color": "#512e5f", "fontWeight": "600", "fontSize": "14px"}}>{"Impersonation alert: " + w}</div> for (i, w) in enumerate(j.warnings)]}
                {if j.credible_fraud_reports > 0 {
                    <div style={{"marginTop": "6px", "fontWeight": "700", "color": "#c0392b"}}>{f"{j.credible_fraud_reports} credible fraud report(s) from workers"}</div>
                }}
                {[
                    <div key={i} style={{"marginTop": "8px", "padding": "8px 10px", "borderRadius": "8px", "background": "#fdedec" if rv.kind == "fraud" else "#e9f7ef", "fontSize": "14px"}}>
                        <b>{rv.author}</b>{f" ({rv.kind}) - Review Verifier: {rv.status}, credibility {rv.credibility}/100"}
                        <div>{rv.text}</div>
                        {if rv.evidence {
                            <div style={{"fontStyle": "italic", "color": "#566573"}}>{"Evidence: " + rv.evidence}</div>
                        }}
                        <div style={{"fontSize": "12px", "color": "#566573"}}>{rv.reason}</div>
                    </div>
                    for (i, rv) in enumerate(j.reviews)
                ]}
                {if review_job == j.id {
                    <div style={{"marginTop": "10px", "display": "grid", "gap": "6px"}}>
                        <div style={{"display": "flex", "gap": "6px", "flexWrap": "wrap"}}>
                            <input placeholder="Your name (optional)" value={review_author} onChange={lambda (e: ChangeEvent) { review_author = e.target.value; }}/>
                            <select value={review_kind} onChange={lambda (e: ChangeEvent) { review_kind = e.target.value; }}>
                                <option value="fraud">Report fraud</option>
                                <option value="positive">Positive experience</option>
                                <option value="other">Other</option>
                            </select>
                        </div>
                        <textarea rows={2} placeholder="What happened? (amounts, dates, what was promised)" value={review_text} onChange={lambda (e: ChangeEvent) { review_text = e.target.value; }}/>
                        <textarea rows={2} placeholder="Evidence: receipt / bank slip details / chat excerpt" value={review_evidence} onChange={lambda (e: ChangeEvent) { review_evidence = e.target.value; }}/>
                        <button disabled={reviewing} onClick={lambda { submit_review(); }}
                            style={{"background": "#922b21", "color": "white", "border": "none", "borderRadius": "8px", "padding": "8px 14px", "fontWeight": "600", "width": "fit-content"}}>
                            {"Review Verifier checking..." if reviewing else "Submit review"}
                        </button>
                    </div>
                } else {
                    <button style={{"marginTop": "10px"}} onClick={lambda -> None { review_job = j.id; }}>Add review with evidence</button>
                }}
            </div>
            for j in jobs
        ]}
    </div>;
}
