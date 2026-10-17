"""Job board: licensed agencies post jobs, the agent team analyses every posting,
and workers add evidence-backed reviews that a Review Verifier agent checks.

Root ─▶ Job ─▶ Review          Agency ─▶ Job          Job ─▶ Contact (shared with pasted offers)
"""
import from datetime { datetime }
import from models { llm }
import from graph { Agency, Contact, Offer, Alert }
import from agents { Investigate, CaseReport, Step }
import from slbfe { search_by_licence, normalise_phone }

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
        top_flags: list[str] = [];
}

node Review {
    has author: str,
        kind: str,
        text: str,
        evidence: str,
        credibility: int = 0,
        status: str = "",
        reason: str = "",
        created_at: str = "";
}

obj ReviewView {
    has author: str,
        kind: str,
        text: str,
        evidence: str,
        credibility: int,
        status: str,
        reason: str,
        created_at: str;
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
        reviews: list[ReviewView],
        credible_fraud_reports: int;
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
        reason: str;
}

sem ReviewAssessment.credibility = "0-100: how credible and specific this review is (concrete amounts, dates, names, consistent with the job) vs vague, emotional, or unrelated.";
sem ReviewAssessment.credible = "True only if the review is specific, relevant to THIS job/agency, and its evidence supports the claim.";
sem ReviewAssessment.reason = "One sentence explaining the assessment.";

def verify_review(job_title: str, agency: str, job_description: str, kind: str, review: str, evidence: str, earlier_reviews: list[str]) -> ReviewAssessment by llm(temperature=0.0);
sem verify_review = "You are the Review Verifier agent on a platform that protects Sri Lankan migrant workers. Judge whether a worker's review of a job posting is credible. Guard against both scams being hidden and fake reviews smearing honest agencies: require specifics (amounts paid, dates, what was promised vs what happened) and evidence that matches the claim. Consider consistency with earlier reviews.";
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
    views = [ReviewView(author=r.author, kind=r.kind, text=r.text, evidence=r.evidence, credibility=r.credibility, status=r.status, reason=r.reason, created_at=r.created_at) for r in reviews];
    fraud = len([r for r in reviews if r.kind == "fraud" and r.status == "credible"]);
    return JobView(id=jid(j), title=j.title, country=j.country, salary=j.salary, description=j.description,
        licence_no=j.licence_no, agency_name=j.agency_name, contact_phone=j.contact_phone, posted_at=j.posted_at,
        band=j.band, score=j.score, summary=j.summary, top_flags=j.top_flags, reviews=views, credible_fraud_reports=fraud);
}

walker:pub PostJob {
    has title: str,
        country: str,
        salary: str,
        description: str,
        licence_no: str,
        contact_phone: str;

    can post with Root entry {
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
        text = f"{ag.name} (SLBFE Licence No {ag.licence_no})\nJob: {self.title} - {self.country}\nSalary: {self.salary}\n{self.description}\nContact: {self.contact_phone}";
        inv = Investigate(text=text, answers=["This job was posted directly on the SafeRata job board by the licensed agency; answer from the posting only."], quiet=True);
        root spawn inv;
        job = Job(title=self.title, country=self.country, salary=self.salary, description=self.description,
            licence_no=ag.licence_no, agency_name=ag.name, contact_phone=self.contact_phone, posted_at=_now());
        c = inv.result;
        if c is not None {
            steps.extend(c.steps);
            job.band = c.band;
            job.score = c.score;
            job.base_score = c.score;
            job.summary = c.judge;
            job.top_flags = [f"{f.title} (+{f.points})" for f in c.flags];
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

walker:pub ListJobs {
    can list with Root entry {
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
        target = jobj(self.job_id);
        if not isinstance(target, Job) {
            report PostResult(ok=False, message="Job not found.");
            disengage;
        }
        job: Job = target;
        steps: list[Step] = [];
        earlier = [f"[{r.kind}, {r.status}] {r.text}" for r in [job -->[?:Review]]];
        a = verify_review(job.title, job.agency_name, job.description, self.kind, self.text, self.evidence, earlier);
        status = "credible" if a.credible and a.credibility >= 60 else "unverified";
        steps.append(Step(agent="Review Verifier", action="assess", detail=f"credibility {a.credibility}/100 -> {status}: {a.reason}"));
        job ++> Review(author=self.author or "Anonymous", kind=self.kind, text=self.text, evidence=self.evidence,
            credibility=a.credibility, status=status, reason=a.reason, created_at=_now());

        credible_fraud = len([r for r in [job -->[?:Review]] if r.kind == "fraud" and r.status == "credible"]);
        new_score = min(100, job.base_score + 30 * credible_fraud);
        if new_score != job.score {
            old_band = job.band;
            job.score = new_score;
            job.band = _band_for(new_score);
            steps.append(Step(agent="Supervisor", action="re-score", detail=f"{credible_fraud} credible fraud report(s): {old_band} -> {job.band} ({new_score}/100)"));
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
