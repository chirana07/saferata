"""Job board: licensed agencies post jobs, the agent team analyses every posting,
and workers add evidence-backed reviews that a Review Verifier agent checks.

Root ─▶ Job ─▶ Review          Agency ─▶ Job          Job ─▶ Contact (shared with pasted offers)
"""
import re;
import from datetime { datetime }
import from models { llm }
import from graph { Agency, Contact, Offer, Alert }
import from agents { Investigate, CaseReport, Step }
import from slbfe { search_by_licence, normalise_phone }
import from rules { SRC_AGENT, parse_salary, to_lkr, match_job }

node Job {
    has title: str,
        country: str,
        salary: str,
        description: str,
        licence_no: str,
        agency_name: str = "",
        contact_phone: str = "",
        posted_at: str = "",
        band: str = "",
        score: int = 0,
        base_score: int = 0,
        summary: str = "",
        top_flags: list[str] = [],
        warnings: list[str] = [],
        occupation: str = "",
        experience_years: int = 0,
        contract_type: str = "",
        contract_months: int = 0,
        accommodation: str = "",
        deductions: str = "",
        monthly_deductions: float = 0.0,
        worker_fee_lkr: float = 0.0,
        soft_flags: list[str] = [],
        hard_points: int = 0,
        appeals: list[str] = [],
        corrections: list[str] = [],
        findings_raw: list[str] = [];
}

node Review {
    has author: str,
        kind: str,
        text: str,
        evidence: str,
        credibility: int = 0,
        status: str = "",
        reason: str = "",
        impersonation: bool = False,
        agency_response: str = "",
        created_at: str = "";
}

obj ReviewView {
    has id: str,
        author: str,
        kind: str,
        text: str,
        evidence: str,
        credibility: int,
        status: str,
        reason: str,
        created_at: str,
        agency_response: str = "";
}

obj FindingView {
    has title: str,
        points: int,
        evidence: str,
        explanation: str,
        source: str;
}

glob SEP = " ||| ";

def _decode_findings(raw: list[str]) -> list[FindingView] {
    out: list[FindingView] = [];
    for r in raw {
        p = r.split(SEP);
        if len(p) == 5 {
            out.append(FindingView(title=p[0], points=int(p[1]), evidence=p[2], explanation=p[3], source=p[4]));
        }
    }
    return out;
}

obj JobView {
    has id: str,
        title: str,
        country: str,
        salary: str,
        description: str,
        licence_no: str,
        agency_name: str,
        contact_phone: str,
        posted_at: str,
        band: str,
        score: int,
        summary: str,
        top_flags: list[str],
        warnings: list[str],
        reviews: list[ReviewView],
        credible_fraud_reports: int,
        occupation: str = "",
        experience_years: int = 0,
        contract_type: str = "",
        contract_months: int = 0,
        accommodation: str = "",
        deductions: str = "",
        salary_amount: float = 0.0,
        salary_currency: str = "",
        salary_lkr: float = 0.0,
        take_home_lkr: float = 0.0,
        worker_fee_lkr: float = 0.0,
        appeals: list[str] = [],
        corrections: list[str] = [],
        appealable: list[str] = [],
        findings: list[FindingView] = [];
}

obj PostResult {
    has ok: bool,
        message: str,
        job: JobView | None = None,
        steps: list[Step] = [];
}

obj ReviewAssessment {
    has credibility: int,
        credible: bool,
        impersonation: bool,
        scam_contacts: list[str],
        reason: str;
}

sem ReviewAssessment.credibility = "0-100: how credible and specific this review is (concrete amounts, dates, names, consistent with the job) vs vague, emotional, or unrelated.";
sem ReviewAssessment.credible = "True only if the review is specific, relevant to THIS job/agency, and its evidence supports the claim.";
sem ReviewAssessment.impersonation = "True if the reviewer was cheated by someone PRETENDING to be from this agency (e.g. used a phone number or account that is not the agency's registered contact), rather than by the agency itself.";
sem ReviewAssessment.scam_contacts = "Phone numbers / accounts the scammer used, copied from the review or evidence. Empty if none.";
sem ReviewAssessment.reason = "One sentence explaining the assessment.";

def verify_review(today: str, job_title: str, agency: str, registered_contacts: list[str], job_description: str, kind: str, review: str, evidence: str, earlier_reviews: list[str]) -> ReviewAssessment by llm(temperature=0.0);
sem verify_review.registered_contacts = "The agency's official phone numbers/email from the SLBFE register. A scammer using a different number is impersonating the agency.";
sem verify_review = "You are the Review Verifier agent on a platform that protects Sri Lankan migrant workers. Judge whether a worker's review of a job posting is credible. Guard against both scams being hidden and fake reviews smearing honest agencies: require specifics (amounts paid, dates, what was promised vs what happened) and evidence that matches the claim. Consider consistency with earlier reviews.";
sem verify_review.today = "Today's date (YYYY-MM-DD). Dates before today are in the past, not the future.";
sem verify_review.evidence = "Evidence the reviewer supplied (e.g. receipt text, chat excerpt, bank slip details).";
sem verify_review.earlier_reviews = "Earlier reviews of the same job, for consistency checks.";

def _now -> str {
    return datetime.now().strftime("%Y-%m-%d %H:%M");
}

def _band_for(score: int) -> str {
    if score >= 60 {
        return "DANGER";
    }
    if score >= 25 {
        return "BE CAREFUL";
    }
    return "LOOKS SAFE";
}

def job_view(j: Job) -> JobView {
    reviews = [r for r in [j -->[?:Review]]];
    views = [ReviewView(id=jid(r), agency_response=r.agency_response, author=r.author, kind=r.kind, text=r.text, evidence=r.evidence, credibility=r.credibility, status=r.status, reason=r.reason, created_at=r.created_at) for r in reviews];
    fraud = len([r for r in reviews if r.kind == "fraud" and r.status == "credible" and not r.impersonation]);
    (amount, cur) = parse_salary(j.salary);
    lkr = to_lkr(amount, cur) if amount > 0 else 0.0;
    deduct_lkr = to_lkr(j.monthly_deductions, cur) if (j.monthly_deductions > 0 and cur) else 0.0;
    return JobView(id=jid(j), title=j.title, country=j.country, salary=j.salary, description=j.description,
        licence_no=j.licence_no, agency_name=j.agency_name, contact_phone=j.contact_phone, posted_at=j.posted_at,
        band=j.band, score=j.score, summary=j.summary, top_flags=j.top_flags, warnings=j.warnings, reviews=views, credible_fraud_reports=fraud,
        occupation=j.occupation, experience_years=j.experience_years, contract_type=j.contract_type, contract_months=j.contract_months,
        accommodation=j.accommodation, deductions=j.deductions, salary_amount=amount, salary_currency=cur,
        salary_lkr=max(lkr, 0.0), take_home_lkr=max(lkr - deduct_lkr, 0.0) if lkr > 0 else 0.0, worker_fee_lkr=j.worker_fee_lkr, appeals=j.appeals,
        corrections=j.corrections, appealable=[f.split("|")[0] for f in j.soft_flags], findings=_decode_findings(j.findings_raw));
}

walker:pub PostJob {
    has title: str,
        country: str,
        salary: str,
        description: str,
        licence_no: str,
        contact_phone: str,
        occupation: str = "",
        experience_years: int = 0,
        contract_type: str = "",
        contract_months: int = 0,
        accommodation: str = "",
        deductions: str = "",
        monthly_deductions: float = 0.0,
        worker_fee_lkr: float = 0.0;

    can post with Root entry {
        if not self.title.strip() or not self.licence_no.strip() or not self.description.strip() {
            report PostResult(ok=False, message="Job title, licence number, and description are required.");
            disengage;
        }
        steps: list[Step] = [Step(agent="Gatekeeper", action="verify_licence", detail=f"checking licence {self.licence_no} on the live SLBFE register")];
        reg = search_by_licence(self.licence_no);
        if not reg.ok {
            report PostResult(ok=False, message="The SLBFE register could not be reached, so the licence cannot be verified. Please try again later.", steps=steps);
            disengage;
        }
        if not reg.records {
            steps.append(Step(agent="Gatekeeper", action="reject", detail=f"licence {self.licence_no} is not on the SLBFE register"));
            report PostResult(ok=False, message=f"Licence {self.licence_no} is not on the SLBFE register of valid agencies. Only licensed agencies can post jobs.", steps=steps);
            disengage;
        }
        ag = reg.records[0];
        steps.append(Step(agent="Gatekeeper", action="verified", detail=f"{ag.name}, valid until {ag.valid_upto}"));
        extra = f"\nContract: {self.contract_type} {self.contract_months} months" if self.contract_type or self.contract_months else "";
        extra += f"\nAccommodation: {self.accommodation}" if self.accommodation else "";
        extra += f"\nDeductions: {self.deductions}" if self.deductions else "";
        extra += f"\nWorker fee: Rs. {self.worker_fee_lkr:,.0f}" if self.worker_fee_lkr > 0 else "";
        text = f"{ag.name} (SLBFE Licence No {ag.licence_no})\nJob: {self.title} - {self.country}\nSalary: {self.salary}\n{self.description}{extra}\nContact: {self.contact_phone}";
        inv = Investigate(text=text, answers=["This job was posted directly on the SafeRata job board by the licensed agency; answer from the posting only."], quiet=True);
        root spawn inv;
        job = Job(title=self.title, country=self.country, salary=self.salary, description=self.description,
            licence_no=ag.licence_no, agency_name=ag.name, contact_phone=self.contact_phone, posted_at=_now(),
            occupation=self.occupation, experience_years=self.experience_years, contract_type=self.contract_type, contract_months=self.contract_months,
            accommodation=self.accommodation, deductions=self.deductions, monthly_deductions=self.monthly_deductions, worker_fee_lkr=self.worker_fee_lkr);
        c = inv.st.result;
        if c is not None {
            steps.extend(c.steps);
            job.band = c.band;
            job.score = c.score;
            job.base_score = c.score;
            job.summary = c.judge;
            job.top_flags = [f"{f.title} (+{f.points})" for f in c.flags];
            job.soft_flags = [f"{f.title}|{f.points}" for f in c.flags if f.source == SRC_AGENT];
            job.findings_raw = [SEP.join([f.title, str(f.points), f.evidence.replace(SEP, " "), f.explanation.replace(SEP, " "), f.source]) for f in c.flags];
            job.hard_points = c.hard_points;
        }
        # Verify contact phone against the agency's official SLBFE registered phones
        norm_contact = normalise_phone(self.contact_phone);
        norm_official = [normalise_phone(p) for p in ag.phones if normalise_phone(p)];
        if norm_contact and norm_official and norm_contact not in norm_official {
            sec_warn = f"SECURITY NOTICE: The contact phone '{self.contact_phone}' is not among {ag.name}'s registered official SLBFE numbers ({', '.join(ag.phones)}). Verify directly with the head office before paying.";
            if not any([sec_warn in w for w in job.warnings]) {
                job.warnings = [sec_warn] + job.warnings;
            }
            if not any(["Contact details not registered" in f for f in job.top_flags]) {
                job.top_flags = ["Contact details not registered to this agency (+30)"] + job.top_flags;
                job.hard_points = job.hard_points + 30;
                job.score = min(100, job.score + 30);
                job.band = _band_for(job.score);
            }
        }
        root ++> job;
        existing = [a for a in [root -->[?:Agency]] if a.licence_no == ag.licence_no];
        node_ag = existing[0] if existing else Agency(licence_no=ag.licence_no, name=ag.name, phones=ag.phones, email=ag.email, valid_upto=ag.valid_upto, checked_at=reg.checked_at);
        if not existing {
            root ++> node_ag;
        }
        node_ag ++> job;
        phone = normalise_phone(self.contact_phone);
        if phone {
            found = [x for x in [root -->[?:Contact]] if x.value == phone];
            ct = found[0] if found else Contact(value=phone, kind="phone");
            if not found {
                root ++> ct;
            }
            job ++> ct;
        }
        report PostResult(ok=True, message=f"Posted. Agent analysis: {job.band} ({job.score}/100).", job=job_view(job), steps=steps);
    }
}

obj AgencyView {
    has id: str,
        licence_no: str,
        name: str,
        phones: list[str],
        email: str,
        valid_upto: str,
        checked_at: str,
        jobs: list[JobView],
        reports: int,
        credible_fraud: int,
        warnings: list[str],
        related_checks: list[str] = [],
        impersonator_numbers: list[str] = [];
}

def agency_view(a: Agency) -> AgencyView {
    jobs = [job_view(j) for j in [a -->[?:Job]]];
    reports = sum([len(j.reviews) for j in jobs]);
    fraud = sum([j.credible_fraud_reports for j in jobs]);
    warns: list[str] = [];
    for j in jobs {
        warns.extend(j.warnings);
    }
    # graph walk: offers people checked that named this agency (Offer --> Agency), and scam numbers reported against its jobs
    related: list[str] = [f"{o.created_at}: {o.job or 'job offer'} in {o.country or '?'} -> {o.verdict}" for o in [a <--[?:Offer]]];
    imp: list[str] = [];
    for j in [a -->[?:Job]] {
        for rv in [j -->[?:Review]] {
            for ct in [rv -->[?:Contact]] {
                if ct.value not in imp {
                    imp.append(ct.value);
                }
            }
        }
    }
    return AgencyView(id=jid(a), licence_no=a.licence_no, name=a.name, phones=a.phones, email=a.email, valid_upto=a.valid_upto,
        checked_at=a.checked_at, jobs=jobs, reports=reports, credible_fraud=fraud, warnings=warns, related_checks=related, impersonator_numbers=imp);
}

def ensure_seed_data(r: Root) {
    if len([r -->[?:Job]]) > 0 {
        return;
    }
    # Official Agency
    ag = Agency(licence_no="3500", name="A T C GLOBAL HOLDINGS (PVT) LTD", phones=["0112818268", "0715217978", "0771605640"],
        email="atcglobalholdings@gmail.com", valid_upto="2027-02-15", checked_at="2026-10-17 10:00");
    r ++> ag;

    for p in ["0112818268", "0715217978", "0771605640"] {
        ct = Contact(value=p, kind="phone");
        r ++> ct;
    }

    # Pre-screened Jobs
    j1 = Job(title="Light vehicle driver", country="Qatar", salary="QAR 2,000 + accommodation",
        description="Employment visa sponsored by the employer. 2-year contract signed in Colombo before departure. Accommodation and transport provided. Any agency charges are paid only at our Nugegoda office against an official receipt, after you sign the contract.",
        licence_no="3500", agency_name="A T C GLOBAL HOLDINGS (PVT) LTD", contact_phone="0112818268", posted_at="2026-10-17 09:30",
        band="LOOKS SAFE", score=0, base_score=0,
        summary="Standard sponsored employment visa under Qatar labour law. Written contract signed prior to departure with official receipts issued exclusively at agency office.",
        top_flags=[], warnings=["Impersonation alert: Kasun reported unauthorized recruiter from 0789123456 demanding registration fees."],
        occupation="driver", experience_years=2, contract_type="employment", contract_months=24, accommodation="provided",
        deductions="none", monthly_deductions=0.0, worker_fee_lkr=0.0);
    r ++> j1;
    ag ++> j1;

    j2 = Job(title="Hotel housekeeping attendant", country="United Arab Emirates", salary="AED 1,600",
        description="Employment visa (work permit) issued by the hotel. 2-year renewable contract. Shared staff accommodation and meals. SLBFE registration done before departure; no fee is collected before the contract is signed.",
        licence_no="3500", agency_name="A T C GLOBAL HOLDINGS (PVT) LTD", contact_phone="0715217978", posted_at="2026-10-17 08:45",
        band="LOOKS SAFE", score=0, base_score=0,
        summary="Hospitality sector employment with full group accommodation and medical insurance included under UAE labour law.",
        top_flags=[], warnings=[],
        occupation="housekeeping", experience_years=1, contract_type="employment", contract_months=24, accommodation="provided",
        deductions="none", monthly_deductions=0.0, worker_fee_lkr=0.0);
    r ++> j2;
    ag ++> j2;

    j3 = Job(title="Commis chef", country="Saudi Arabia", salary="SAR 2,400",
        description="Employment visa sponsored by the employer. NVQ Level 3 cookery preferred. 2-year contract, accommodation provided, 30 days annual leave. Contract and fees explained at our office with an official receipt for every payment.",
        licence_no="3500", agency_name="A T C GLOBAL HOLDINGS (PVT) LTD", contact_phone="0771605640", posted_at="2026-10-17 07:15",
        band="LOOKS SAFE", score=0, base_score=0,
        summary="Verified restaurant group sponsorship with verified employer contract in Saudi Arabia.",
        top_flags=[], warnings=[],
        occupation="chef", experience_years=2, contract_type="employment", contract_months=24, accommodation="provided",
        deductions="none", monthly_deductions=0.0, worker_fee_lkr=0.0);
    r ++> j3;
    ag ++> j3;

    j4 = Job(title="MIG Welder / Fabricator", country="Kuwait", salary="KWD 180 + food allowance",
        description="Industrial steel construction project in Kuwait. Direct work visa issued by contractor. 2-year contract, medical cover, overtime paid at 1.5x. SLBFE pre-departure registration mandatory.",
        licence_no="3500", agency_name="A T C GLOBAL HOLDINGS (PVT) LTD", contact_phone="0112818268", posted_at="2026-10-17 06:00",
        band="LOOKS SAFE", score=0, base_score=0,
        summary="Industrial fabrication work visa with overtime provisions and mandatory SLBFE clearance.",
        top_flags=[], warnings=[],
        occupation="welder", experience_years=3, contract_type="employment", contract_months=24, accommodation="provided",
        deductions="none", monthly_deductions=0.0, worker_fee_lkr=0.0);
    r ++> j4;
    ag ++> j4;

    # Worker reviews & impersonation reports
    scam_ct = Contact(value="0789123456", kind="phone");
    r ++> scam_ct;

    rv1 = Review(author="Kasun", kind="fraud",
        text="On 8 Oct 2026 a man called from 0789123456 saying he recruits Qatar drivers for this agency. He took Rs. 75,000 by bank transfer as a 'registration fee' and stopped answering. When I visited the Nugegoda office they said he is not their staff and they never charge before the contract.",
        evidence="Bank transfer 08-10-2026, Rs. 75,000 to an individual's account; WhatsApp from 0789123456: 'pay today to reserve your Qatar driver seat'",
        credibility=90, status="credible",
        reason="Credible impersonation report backed by bank transaction and WhatsApp evidence.",
        impersonation=True,
        agency_response="Confirmed: 0789123456 is not affiliated with ATC Global. We never collect fees outside our Nugegoda office.",
        created_at="2026-10-17 10:15");
    j1 ++> rv1;
    rv1 ++> scam_ct;

    rv2 = Review(author="Dilani", kind="positive",
        text="Placed as housekeeping attendant in Dubai in March 2026. The contract I received on arrival was identical to the one I signed in Colombo, and the only fee was paid at the office with a receipt.",
        evidence="Official receipt from the agency office; signed contract copy dated 02-03-2026",
        credibility=95, status="credible",
        reason="Verified review with official SLBFE-aligned receipt.",
        impersonation=False, agency_response="", created_at="2026-10-17 10:30");
    j2 ++> rv2;

    # Community scam checks (Offers)
    off1 = Offer(
        text="URGENT HIRING!!! IT / Data Entry jobs in THAILAND. Salary USD 1500 per month. Travel on tourist visa, pay Rs. 150,000 processing fee to confirm seat. Deposit to Commercial Bank account. WhatsApp +94 76 555 1234",
        job="IT / Data Entry", country="Thailand", agency_name="Unregistered Online Recruiter", verdict="DANGER", score=85,
        summary="Tourist visa scam for cyber scam compound / trafficking risk. Advance fee demanded.", created_at="2026-10-17 11:00");
    r ++> off1;
    thai_ct = Contact(value="0765551234", kind="phone");
    r ++> thai_ct;
    off1 ++> thai_ct;

    off2 = Offer(
        text="Housemaid job in Dubai, salary AED 1500. Go on 3-month visit visa first. Sponsor will keep passport for safety. Contact Mrs. Silva 0712223344, pay Rs. 60,000 for ticket.",
        job="Housemaid", country="UAE", agency_name="Individual Broker (Mrs. Silva)", verdict="DANGER", score=90,
        summary="Visit visa employment trap and illegal withholding of passport. High risk of exploitation.", created_at="2026-10-17 11:30");
    r ++> off2;
    dubai_ct = Contact(value="0712223344", kind="phone");
    r ++> dubai_ct;
    off2 ++> dubai_ct;

    off3 = Offer(
        text="Security guard / helper jobs in RUSSIA. Salary USD 2500. Tourist visa provided. Leave within 1 week. Contact WhatsApp +7 925 000 1122",
        job="Security Guard", country="Russia", agency_name="Unknown Telegram Channel", verdict="DANGER", score=80,
        summary="High-risk recruitment to conflict zone on tourist visa without SLBFE clearance.", created_at="2026-10-17 12:00");
    r ++> off3;
    rus_ct = Contact(value="79250001122", kind="phone");
    r ++> rus_ct;
    off3 ++> rus_ct;

    off4 = Offer(
        text="A T C GLOBAL HOLDINGS (PVT) LTD - Licence No 3500. Qatar House Driver. Registration fee Rs. 75,000 must be paid before interview. WhatsApp 0789 123 456",
        job="House Driver", country="Qatar", agency_name="A T C GLOBAL HOLDINGS (PVT) LTD", verdict="DANGER", score=75,
        summary="Impersonation scam using legitimate agency licence 3500 to extort upfront registration fee.", created_at="2026-10-17 12:30");
    r ++> off4;
    off4 ++> ag;
    off4 ++> scam_ct;
}

"""Companies screen: every agency the system has verified on the SLBFE register, with its jobs and worker reports."""
walker:pub ListAgencies {
    can list with Root entry {
        ensure_seed_data(root);
        for a in [root -->[?:Agency]] {
            report agency_view(a);
        }
    }
}

obj ContactCheckResult {
    has value: str,
        status: str,
        agency_name: str = "",
        licence_no: str = "",
        valid_upto: str = "",
        earlier_checks: int = 0,
        danger_checks: int = 0,
        message: str = "";
}

"""Quick Recruiter Phone Search: checks a contact against official agencies, known impersonators, and community checks."""
walker:pub CheckContact {
    has value: str;

    can check with Root entry {
        ensure_seed_data(root);
        raw = self.value.strip();
        phone = normalise_phone(raw) if re.search(r"\d{9}", re.sub(r"\D", "", raw)) else raw.lower().strip();
        if not phone {
            report ContactCheckResult(value=raw, status="unverified", message="Please enter a valid phone number or email address.");
            disengage;
        }

        # 1. Check if registered to an official agency
        for a in [root -->[?:Agency]] {
            norm_phones = [normalise_phone(p) for p in a.phones if normalise_phone(p)];
            if phone in norm_phones or (a.email and phone == a.email.lower().strip()) {
                report ContactCheckResult(
                    value=phone,
                    status="official_agency",
                    agency_name=a.name,
                    licence_no=a.licence_no,
                    valid_upto=a.valid_upto,
                    message=f"Verified official contact for {a.name} (SLBFE Licence {a.licence_no})."
                );
                disengage;
            }
        }

        # 2. Check if flagged in any Agency impersonator list
        for a in [root -->[?:Agency]] {
            v = agency_view(a);
            if phone in [normalise_phone(p) for p in v.impersonator_numbers] {
                report ContactCheckResult(
                    value=phone,
                    status="flagged_impersonator",
                    agency_name=a.name,
                    licence_no=a.licence_no,
                    message=f"CRITICAL WARNING: This contact was flagged by workers for impersonating {a.name} (Licence {a.licence_no}). Do not transfer funds!"
                );
                disengage;
            }
        }

        # 3. Check community investigations
        found = [c for c in [root -->[?:Contact]] if c.value == phone];
        if found {
            ct = found[0];
            offers = [o for o in [ct <--[?:Offer]]];
            danger = [o for o in offers if o.verdict == "DANGER"];
            if len(danger) > 0 {
                report ContactCheckResult(
                    value=phone,
                    status="community_danger",
                    earlier_checks=len(offers),
                    danger_checks=len(danger),
                    message=f"CAUTION: This contact appeared in {len(offers)} earlier check(s), with {len(danger)} judged DANGER."
                );
                disengage;
            }
        }

        # 4. Unverified contact
        report ContactCheckResult(
            value=phone,
            status="unverified",
            message=f"Unregistered Contact: '{phone}' is not registered to any licensed agency on file. Unofficial agents operate outside SLBFE legal protection."
        );
    }
}

obj JobMatch {
    has job_id: str,
        match: int,
        reasons: list[str],
        cautions: list[str];
}

"""Profile matching. The profile lives in the worker's browser and is sent per request; nothing about the person is stored."""
walker:pub MatchJobs {
    has occupation: str = "",
        skills: list[str] = [],
        destinations: list[str] = [],
        min_salary_lkr: float = 0.0,
        experience_years: int = 0,
        needs_accommodation: bool = False;

    can rank with Root entry {
        ensure_seed_data(root);
        for j in [root -->[?:Job]] {
            v = job_view(j);
            (m, why, warn) = match_job(self.occupation, self.skills, self.destinations, self.min_salary_lkr, self.experience_years, self.needs_accommodation,
                v.title + " " + v.occupation + " " + v.description + " " + v.accommodation, v.country, v.salary_lkr, v.experience_years, v.accommodation);
            if v.band != "LOOKS SAFE" {
                warn.append(f"Safety: {v.band} ({v.score}/100). A high match does not mean the job is safe.");
            }
            report JobMatch(job_id=v.id, match=m, reasons=why, cautions=warn);
        }
    }
}

walker:pub ListJobs {
    can list with Root entry {
        ensure_seed_data(root);
        jobs = [j for j in [root -->[?:Job]]];
        jobs.reverse();
        for j in jobs {
            report job_view(j);
        }
    }
}

walker:pub AddReview {
    has job_id: str,
        author: str,
        kind: str,
        text: str,
        evidence: str;

    can add with Root entry {
        if not self.text.strip() {
            report PostResult(ok=False, message="Review text cannot be empty.");
            disengage;
        }
        target = jobj(self.job_id);
        if not isinstance(target, Job) {
            report PostResult(ok=False, message="Job not found.");
            disengage;
        }
        job: Job = target;
        steps: list[Step] = [];
        ags = [a for a in [root -->[?:Agency]] if a.licence_no == job.licence_no];
        official: list[str] = (ags[0].phones + [ags[0].email]) if ags else [];
        earlier = [f"[{r.kind}, {r.status}] {r.text}" for r in [job -->[?:Review]]];
        a = verify_review(_now()[:10], job.title, job.agency_name, official, job.description, self.kind, self.text, self.evidence, earlier);
        status = "credible" if a.credible and a.credibility >= 60 else "unverified";
        imp = a.impersonation and self.kind == "fraud";
        steps.append(Step(agent="Review Verifier", action="assess", detail=f"credibility {a.credibility}/100 -> {status}" + (" (impersonation of the agency)" if imp else "") + f": {a.reason}"));
        rv = Review(author=self.author or "Anonymous", kind=self.kind, text=self.text, evidence=self.evidence,
            credibility=a.credibility, status=status, reason=a.reason, impersonation=imp, created_at=_now());
        job ++> rv;

        if status == "credible" and imp {
            scam = [normalise_phone(c) for c in a.scam_contacts if normalise_phone(c) and normalise_phone(c) not in official];
            if scam {
                job.warnings = job.warnings + [f"Scammers are impersonating this agency using {', '.join(scam)}. Only trust the registered numbers: {', '.join([o for o in official if o])}."];
            }
            warned = 0;
            for v in scam {
                found = [x for x in [root -->[?:Contact]] if x.value == v];
                ct = found[0] if found else Contact(value=v, kind="phone");
                if not found {
                    root ++> ct;
                }
                rv ++> ct;
                for o in [ct <--[?:Offer]] {
                    o ++> Alert(message=f"The number {v} in an offer you checked has been credibly reported for impersonating {job.agency_name}.", created_at=_now());
                    warned += 1;
                }
            }
            steps.append(Step(agent="Network Guardian", action="impersonation_alert", detail=f"flagged scam number(s) {', '.join(scam) or 'none given'}; the agency's own score is unchanged; warned {warned} earlier check(s)"));
        }

        credible_fraud = len([r for r in [job -->[?:Review]] if r.kind == "fraud" and r.status == "credible" and not r.impersonation]);
        new_score = min(100, job.base_score + 30 * credible_fraud);
        if new_score != job.score {
            old_band = job.band;
            job.score = new_score;
            job.band = _band_for(new_score);
            steps.append(Step(agent="Supervisor", action="re-score", detail=f"{credible_fraud} credible fraud report(s) against the agency: {old_band} -> {job.band} ({new_score}/100)"));
            if job.band == "DANGER" and old_band != "DANGER" {
                warned = 0;
                for ct in [job -->[?:Contact]] {
                    for o in [ct <--[?:Offer]] {
                        o ++> Alert(message=f"The number {ct.value} in an offer you checked belongs to a job that workers have credibly reported as fraud.", created_at=_now());
                        warned += 1;
                    }
                }
                steps.append(Step(agent="Network Guardian", action="alert_walk", detail=f"warned {warned} earlier check(s) linked by contact {job.contact_phone}"));
            }
        }
        report PostResult(ok=True, message=f"Review {status}.", job=job_view(job), steps=steps);
    }
}

obj AppealDecision {
    has accept: bool,
        reason: str;
}

sem AppealDecision.accept = "True only if the agency's explanation and evidence clearly show the finding was wrong or is now fixed (e.g. the fee was removed, the clause was misread).";
sem AppealDecision.reason = "One or two sentences explaining the decision to both the agency and workers.";

def review_appeal(today: str, finding: str, job_description: str, explanation: str, evidence: str) -> AppealDecision by llm(temperature=0.0);
sem review_appeal = "You are the Appeal Reviewer agent on a platform protecting Sri Lankan migrant workers. An agency disputes an AI finding on its job listing. Accept the appeal only if the explanation and evidence clearly rebut the finding as it applies to the listing text. Be fair to honest agencies but never accept vague denials.";

def _rescore(j: Job) {
    soft = sum([int(f.split("|")[1]) for f in j.soft_flags if "|" in f]);
    base = min(100, j.hard_points + min(soft, 20));
    fraud = len([r for r in [j -->[?:Review]] if r.kind == "fraud" and r.status == "credible" and not r.impersonation]);
    j.base_score = base;
    j.score = min(100, base + 30 * fraud);
    j.band = _band_for(j.score);
}

"""Agency disputes an agent-judgement finding on its listing. Official register/rule findings cannot be appealed here."""
walker:pub AppealFinding {
    has job_id: str,
        finding: str,
        explanation: str,
        evidence: str = "",
        agency_phone: str = "";

    can appeal with Root entry {
        if not self.explanation.strip() {
            report PostResult(ok=False, message="Appeal explanation cannot be empty.");
            disengage;
        }
        target = jobj(self.job_id);
        if not isinstance(target, Job) {
            report PostResult(ok=False, message="Job not found.");
            disengage;
        }
        job: Job = target;
        steps: list[Step] = [];

        # Agency identity verification against live SLBFE register
        reg = search_by_licence(job.licence_no);
        ag_phones: list[str] = [];
        if reg.ok and reg.records {
            ag_phones = [normalise_phone(p) for p in reg.records[0].phones if normalise_phone(p)];
        }
        if self.agency_phone.strip() {
            caller_phone = normalise_phone(self.agency_phone);
            if ag_phones and caller_phone not in ag_phones {
                steps.append(Step(agent="Gatekeeper", action="auth_failed", detail=f"Phone {self.agency_phone} is not registered to {job.agency_name} on SLBFE register"));
                report PostResult(ok=False, message=f"Identity verification failed: '{self.agency_phone}' is not a registered contact phone for {job.agency_name}. Only verified agency representatives may file appeals.", job=job_view(job), steps=steps);
                disengage;
            }
            steps.append(Step(agent="Gatekeeper", action="auth_verified", detail=f"Agency identity authenticated via registered phone {self.agency_phone}"));
        } else {
            steps.append(Step(agent="Gatekeeper", action="auth_advisory", detail="Appeal filed without registered phone challenge"));
        }

        titles = [f.split("|")[0] for f in job.soft_flags];
        if self.finding not in titles {
            steps.append(Step(agent="Appeal Reviewer", action="refuse", detail=f"'{self.finding}' is an official register or rule finding, which only the SLBFE can change"));
            report PostResult(ok=False, message="Only agent-judgement findings can be appealed here. Official register and rule findings must be resolved with the SLBFE.", job=job_view(job), steps=steps);
            disengage;
        }
        d = review_appeal(_now()[:10], self.finding, job.description, self.explanation, self.evidence);
        old_band = job.band;
        if d.accept {
            job.soft_flags = [f for f in job.soft_flags if f.split("|")[0] != self.finding];
            job.top_flags = [f for f in job.top_flags if not f.startswith(self.finding + " (")];
            job.findings_raw = [r for r in job.findings_raw if not r.startswith(self.finding + SEP)];
            _rescore(job);
        }
        filer_tag = f" (Verified via {self.agency_phone})" if self.agency_phone.strip() else "";
        job.appeals = job.appeals + [f"{_now()} · {self.finding}: {'accepted' if d.accept else 'rejected'}{filer_tag}. {d.reason}"];
        steps.append(Step(agent="Appeal Reviewer", action="decide", detail=f"{'accepted' if d.accept else 'rejected'}: {d.reason}"));
        if d.accept {
            steps.append(Step(agent="Supervisor", action="re-score", detail=f"{old_band} -> {job.band} ({job.score}/100)"));
        }
        report PostResult(ok=True, message=f"Appeal {'accepted' if d.accept else 'rejected'}.", job=job_view(job), steps=steps);
    }
}

"""Agency's public reply to a worker review (shown under the review)."""
walker:pub RespondToReview {
    has review_id: str,
        response: str,
        agency_phone: str = "";

    can respond with Root entry {
        if not self.response.strip() {
            report PostResult(ok=False, message="Agency response cannot be empty.");
            disengage;
        }
        target = jobj(self.review_id);
        if not isinstance(target, Review) {
            report PostResult(ok=False, message="Review not found.");
            disengage;
        }
        rv: Review = target;
        parent_jobs = [j for j in [rv <--[?:Job]]];
        prefix = "";
        if parent_jobs {
            pjob = parent_jobs[0];
            reg = search_by_licence(pjob.licence_no);
            ag_phones: list[str] = [];
            if reg.ok and reg.records {
                ag_phones = [normalise_phone(p) for p in reg.records[0].phones if normalise_phone(p)];
            }
            if self.agency_phone.strip() {
                caller_phone = normalise_phone(self.agency_phone);
                if ag_phones and caller_phone not in ag_phones {
                    report PostResult(ok=False, message=f"Identity verification failed: '{self.agency_phone}' is not a registered phone for {pjob.agency_name}. Only the verified agency can post official responses.");
                    disengage;
                }
                prefix = f"[{pjob.agency_name} Verified Response · {self.agency_phone}]: ";
            } else {
                prefix = f"[{pjob.agency_name} Official Response]: ";
            }
        }
        rv.agency_response = (prefix + self.response.strip())[:800];
        report PostResult(ok=True, message="Response published under the review.");
    }
}

"""Request a correction to a listing's facts; logged on the job for moderators."""
walker:pub RequestCorrection {
    has job_id: str,
        details: str;

    can request with Root entry {
        if not self.details.strip() {
            report PostResult(ok=False, message="Correction details cannot be empty.");
            disengage;
        }
        target = jobj(self.job_id);
        if not isinstance(target, Job) {
            report PostResult(ok=False, message="Job not found.");
            disengage;
        }
        job: Job = target;
        job.corrections = job.corrections + [f"{_now()} · {self.details.strip()[:500]}"];
        report PostResult(ok=True, message="Correction request logged for moderation.", job=job_view(job));
    }
}
