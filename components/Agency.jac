"""Agency portal, ported from the layout-coder design: live SLBFE licence gate + full agent analysis + appeals."""

import from "lucide-react" { Check, X, Upload, AlertTriangle, Loader2 }
import from jobboard { PostJob, ListJobs, AppealFinding, PostResult, JobView }
import from agents { Step }
import from .ui { risk_of, SafetyIndicator, VerifyBadge, LiveTag, PageHeader }

glob INPUT = "mt-1 h-10 w-full rounded-md border border-input bg-card px-3 text-sm font-normal focus:border-primary";

def:pub AgencyPortal(onPosted: Callable[[], None]) -> JsxElement {
    has role: str = "",
        country: str = "",
        salary: str = "",
        currency: str = "QAR",
        fee: str = "",
        deductions: str = "",
        deduction_total: str = "",
        visa: str = "Employment visa",
        contract_months: str = "24",
        contract_type: str = "Fixed term",
        accommodation: str = "",
        occupation: str = "",
        experience: str = "0",
        licence_no: str = "",
        contact_phone: str = "",
        notes: str = "",
        files: list[str] = [],
        posting: bool = False,
        message: str = "",
        last_steps: list[Step] = [],
        mine: list[JobView] = [],
        appeal_job: str = "",
        appeal_finding: str = "",
        appeal_text: str = "",
        appealing: bool = False;

    async def load_mine(lic: str) -> None {
        if not lic.strip() {
            return;
        }
        res = root spawn ListJobs();
        if res.reports {
            mine = [j for j in res.reports if j.licence_no == lic.strip()];
        }
    }

    def fill_sample {
        role = "Factory machine operator";
        country = "Malaysia";
        salary = "1700";
        currency = "MYR";
        fee = "200000";
        deductions = "Levy 60, food 150";
        deduction_total = "210";
        visa = "Employment visa";
        contract_months = "24";
        accommodation = "Free shared hostel";
        occupation = "Manufacturing";
        licence_no = "3500";
        contact_phone = "0765551234";
        notes = "Pay the Rs. 200,000 service charge to our officer's account before medical. Passport will be kept by the company for safety.";
        load_mine("3500");
    }

    async def submit -> None {
        posting = True;
        message = "";
        last_steps = [];
        desc = f"{visa}. {contract_type} contract, {contract_months} months. Accommodation: {accommodation or 'not stated'}. Deductions: {deductions or 'none'}. Worker fee: Rs. {fee or '0'}. {notes}";
        result = root spawn PostJob(title=role, country=country, salary=f"{currency} {salary}", description=desc, licence_no=licence_no, contact_phone=contact_phone,
            occupation=occupation, experience_years=int(experience or "0"), contract_type=contract_type, contract_months=int(contract_months or "0"),
            accommodation=accommodation, deductions=deductions, monthly_deductions=float(deduction_total or "0"), worker_fee_lkr=float(fee or "0"));
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

    async def appeal -> None {
        appealing = True;
        result = root spawn AppealFinding(job_id=appeal_job, finding=appeal_finding, explanation=appeal_text, evidence="");
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
        appealing = False;
    }

    def pick_files(e: ChangeEvent) {
        names: list[str] = [];
        fl: any = e.target.files;
        count: int = int(fl.length) if fl else 0;
        for i in range(count) {
            names.append(str(fl[i].name));
        }
        files = names;
    }

    checks: list[list[str]] = [
        ["Role and destination", "ok" if role and country else ""],
        ["Basic salary stated", "ok" if salary else ""],
        ["Employment visa (not tourist)", "ok" if visa and "tourist" not in visa.lower() and "visit" not in visa.lower() else ""],
        ["Contract duration", "ok" if contract_months and contract_months != "0" else ""],
        ["Accommodation disclosed", "ok" if accommodation else ""],
        ["Worker fee disclosed", "ok" if fee != "" else ""],
        ["SLBFE licence number", "ok" if licence_no else ""],
        ["Supporting document attached", "ok" if len(files) > 0 else ""]
    ];

    return <div>
        <PageHeader eyebrow="Agency portal" title="Publish a verified listing">
            <div className="text-right text-sm"><p className="font-mono">{licence_no or "Licence checked on submit"}</p><div className="mt-1 flex items-center justify-end gap-2"><LiveTag label="Live SLBFE gate"/></div></div>
        </PageHeader>
        <div className="grid gap-8 lg:grid-cols-[1.5fr_1fr]">
            <div className="space-y-6 rounded-xl border border-border bg-card p-6 shadow-card">
                <div className="flex items-center justify-between"><h2 className="text-xl font-bold">New listing</h2><button onClick={lambda -> None { fill_sample(); }} className="rounded-md border border-border px-3 py-1.5 text-xs font-semibold">Fill sample</button></div>
                <fieldset className="grid gap-4 sm:grid-cols-2"><legend className="eyebrow mb-2">Agency</legend>
                    <label className="block text-xs font-semibold">SLBFE licence number<input value={licence_no} onChange={lambda (e: ChangeEvent) { licence_no = e.target.value; if len(e.target.value.strip()) >= 3 { load_mine(e.target.value.strip()); } }} className={INPUT}/></label>
                    <label className="block text-xs font-semibold">Contact phone<input value={contact_phone} onChange={lambda (e: ChangeEvent) { contact_phone = e.target.value; }} className={INPUT}/></label>
                </fieldset>
                <fieldset className="grid gap-4 sm:grid-cols-2"><legend className="eyebrow mb-2">Role</legend>
                    <label className="block text-xs font-semibold">Job title<input value={role} onChange={lambda (e: ChangeEvent) { role = e.target.value; }} className={INPUT}/></label>
                    <label className="block text-xs font-semibold">Destination country<input value={country} onChange={lambda (e: ChangeEvent) { country = e.target.value; }} className={INPUT}/></label>
                    <label className="block text-xs font-semibold">Occupation group<input value={occupation} onChange={lambda (e: ChangeEvent) { occupation = e.target.value; }} className={INPUT}/></label>
                    <label className="block text-xs font-semibold">Experience required (years)<input value={experience} onChange={lambda (e: ChangeEvent) { experience = e.target.value; }} className={INPUT}/></label>
                </fieldset>
                <fieldset className="grid gap-4 sm:grid-cols-3"><legend className="eyebrow mb-2">Pay</legend>
                    <label className="block text-xs font-semibold">Basic monthly salary<input type="number" value={salary} onChange={lambda (e: ChangeEvent) { salary = e.target.value; }} className={INPUT}/></label>
                    <label className="block text-xs font-semibold">Currency<select value={currency} onChange={lambda (e: ChangeEvent) { currency = e.target.value; }} className={INPUT}>{[<option key={c} value={c}>{c}</option> for c in ["QAR", "SAR", "AED", "KWD", "OMR", "MYR", "JPY", "KRW", "USD"]]}</select></label>
                    <label className="block text-xs font-semibold">Fee charged to worker (LKR)<input type="number" value={fee} onChange={lambda (e: ChangeEvent) { fee = e.target.value; }} className={INPUT}/></label>
                    <div className="sm:col-span-2"><label className="block text-xs font-semibold">Deductions (e.g. food 200, transport 0)<input value={deductions} onChange={lambda (e: ChangeEvent) { deductions = e.target.value; }} className={INPUT}/></label></div>
                    <label className="block text-xs font-semibold">Total deductions / month<input type="number" value={deduction_total} onChange={lambda (e: ChangeEvent) { deduction_total = e.target.value; }} className={INPUT}/></label>
                </fieldset>
                <fieldset className="grid gap-4 sm:grid-cols-3"><legend className="eyebrow mb-2">Visa, contract & housing</legend>
                    <label className="block text-xs font-semibold">Visa category<input value={visa} onChange={lambda (e: ChangeEvent) { visa = e.target.value; }} className={INPUT}/></label>
                    <label className="block text-xs font-semibold">Contract type<select value={contract_type} onChange={lambda (e: ChangeEvent) { contract_type = e.target.value; }} className={INPUT}><option value="Fixed term">Fixed term</option><option value="Renewable">Renewable</option><option value="Seasonal">Seasonal</option></select></label>
                    <label className="block text-xs font-semibold">Contract duration (months)<input value={contract_months} onChange={lambda (e: ChangeEvent) { contract_months = e.target.value; }} className={INPUT}/></label>
                    <div className="sm:col-span-3"><label className="block text-xs font-semibold">Accommodation<input value={accommodation} onChange={lambda (e: ChangeEvent) { accommodation = e.target.value; }} className={INPUT}/></label></div>
                    <div className="sm:col-span-3"><label className="block text-xs font-semibold">Other terms (fees, payment, documents)<textarea rows={3} value={notes} onChange={lambda (e: ChangeEvent) { notes = e.target.value; }} className="mt-1 w-full rounded-md border border-input bg-card p-3 text-sm font-normal"/></label></div>
                </fieldset>
                <div>
                    <p className="eyebrow mb-2">Documents</p>
                    <label className="flex cursor-pointer flex-col items-center gap-2 rounded-lg border border-dashed border-input bg-muted/50 px-4 py-6 text-center text-sm hover:border-primary">
                        <Upload className="h-5 w-5 text-muted-foreground"/>
                        <span><b>Choose files</b> — demand letter, contract template</span>
                        <span className="text-xs text-muted-foreground">Only file names are kept: document upload and analysis are not built yet.</span>
                        <input type="file" multiple={True} className="sr-only" onChange={pick_files}/>
                    </label>
                    {if len(files) > 0 { <ul className="mt-2 text-xs">{[<li key={n} className="font-mono">{"· " + n}</li> for n in files]}</ul> }}
                </div>
                <p className="text-xs text-muted-foreground">The licence is checked live on the SLBFE register, then the full agent team analyses the listing before workers see it.</p>
                <button disabled={posting} onClick={lambda { submit(); }} className="inline-flex h-11 items-center gap-2 rounded-md bg-primary px-5 text-sm font-semibold text-primary-foreground hover:bg-primary-deep disabled:opacity-60">{if posting { <Loader2 className="h-4 w-4 animate-spin"/> }} Submit for verification</button>
                {if message {
                    <div className="rounded-md bg-secondary p-3 text-xs">
                        <p className="font-semibold text-primary-deep">{message}</p>
                        <ol className="mt-1 list-decimal space-y-0.5 pl-4">{[<li key={k}><span className="font-semibold">{s.agent}</span>{" · " + s.action + ": " + s.detail[:140]}</li> for (k, s) in enumerate(last_steps)]}</ol>
                    </div>
                }}
            </div>
            <div className="space-y-6">
                <section className="rounded-xl border border-border bg-card p-5">
                    <h2 className="font-bold">Pre-publication checklist</h2>
                    <ul className="mt-3 space-y-2 text-sm">{[<li key={c[0]} className="flex items-center gap-2">{if c[1] { <Check className="h-4 w-4 text-safe"/> } else { <X className="h-4 w-4 text-muted-foreground"/> }}<span className={"" if c[1] else "text-muted-foreground"}>{c[0]}</span></li> for c in checks]}</ul>
                </section>
                <section className="rounded-xl border border-border bg-card p-5">
                    <h2 className="font-bold">Your listings</h2>
                    {if len(mine) == 0 {
                        <p className="mt-2 text-sm text-muted-foreground">No listings submitted in this session.</p>
                    } else {
                        <ul className="mt-3 divide-y divide-border">
                            {[
                                <li key={j.id} className="py-3 text-sm">
                                    <div className="flex items-start justify-between gap-2"><span className="font-semibold">{j.title + " · " + j.country}</span><SafetyIndicator risk={risk_of(j.band, j.score)} compact={True}/></div>
                                    <p className="font-mono text-xs text-muted-foreground">{f"{j.salary} · fee LKR {j.worker_fee_lkr:,.0f} · {j.score}/100"}</p>
                                    {[<p key={k} className="mt-1 text-xs font-semibold text-primary-deep">{"Appeal " + ap}</p> for (k, ap) in enumerate(j.appeals)]}
                                    {if len(j.appealable) > 0 {
                                        <div className="mt-2 rounded-md bg-caution-soft p-3 text-xs">
                                            <p className="flex items-center gap-1 font-semibold"><AlertTriangle className="h-3.5 w-3.5"/>{f" {len(j.appealable)} agent finding(s) can be disputed"}</p>
                                            {if appeal_job == j.id {
                                                <div className="mt-2 space-y-2">
                                                    <select value={appeal_finding} onChange={lambda (e: ChangeEvent) { appeal_finding = e.target.value; }} className="h-9 w-full rounded border border-input bg-card px-2">{[<option key={k} value={f}>{f}</option> for (k, f) in enumerate(j.appealable)]}</select>
                                                    <textarea value={appeal_text} onChange={lambda (e: ChangeEvent) { appeal_text = e.target.value; }} rows={2} placeholder="Explain and reference evidence…" className="w-full rounded border border-input bg-card p-2"/>
                                                    <button disabled={appealing} onClick={lambda { appeal(); }} className="rounded bg-ink px-3 py-1.5 font-semibold text-ink-foreground">{"Appeal Reviewer deciding..." if appealing else "Send appeal"}</button>
                                                </div>
                                            } else {
                                                <button onClick={lambda -> None { appeal_job = j.id; appeal_finding = j.appealable[0]; }} className="mt-1 font-semibold text-primary-deep underline">Dispute this finding</button>
                                            }}
                                        </div>
                                    }}
                                </li>
                                for j in mine
                            ]}
                        </ul>
                    }}
                    <p className="mt-3 text-xs text-muted-foreground">Only agent-judgement findings can be appealed. Official register and rule findings are resolved with the SLBFE.</p>
                </section>
                <section className="rounded-xl border border-border bg-card p-5 text-sm">
                    <h2 className="font-bold">Status legend</h2>
                    <div className="mt-3 flex flex-wrap gap-2">{[<VerifyBadge key={s} state={s}/> for s in ["verified", "expired", "rejected", "unverified"]]}</div>
                </section>
            </div>
        </div>
    </div>;
}
