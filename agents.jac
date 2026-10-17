"""The agent team: Extractor -> Lead Investigator (ReAct, own tool choices, may ask the
person) -> chosen Specialists -> Prosecutor vs Defender -> Judge -> Critic -> Scorer -> Advisor.
Every action is logged to `steps` so the UI can show the investigation live.
"""
import re;
import from concurrent.futures { ThreadPoolExecutor }
import from datetime { datetime }
import from models { llm }
import from graph {
    Agency, Contact, Offer, Alert,
    OfferFacts, SoftFlag, Specialist, InvestigationNotes, JudgeRuling, Advice
}
import from rules {
    RedFlag, Score, RegisterStatus,
    SRC_REGISTER, SRC_COMMUNITY, SRC_GUIDANCE, GENERAL_GUIDANCE,
    country_note, rule_flags, soft_to_red, critic, dedupe, score_flags
}
import from slbfe { AgencyRecord, RegisterResult, search_by_licence, search_by_name, normalise_phone }

obj Step {
    has agent: str,
        action: str,
        detail: str;
}

obj Source {
    has name: str,
        detail: str,
        url: str = "";
}

obj CaseReport {
    has status: str,
        questions: list[str] = [],
        band: str = "",
        score: int = 0,
        hard_points: int = 0,
        soft_points: int = 0,
        flags: list[RedFlag] = [],
        removed: list[str] = [],
        prosecution: str = "",
        defence: str = "",
        judge: str = "",
        advice: Advice | None = None,
        agency: AgencyRecord | None = None,
        register_status: str = "",
        community: list[str] = [],
        alerts_sent: int = 0,
        facts: OfferFacts | None = None,
        sources: list[Source] = [],
        steps: list[Step] = [],
        offer_id: str = "";
}

# ---------------- LLM agents (plain functions) ----------------

def extract_facts(offer: str) -> OfferFacts by llm(temperature=0.0);
sem extract_facts = "You are the Extractor agent. Read a foreign job offer (Facebook ad, WhatsApp message or contract) aimed at Sri Lankan workers and extract the facts. Do not invent anything that is not in the text.";
sem extract_facts.offer = "The raw job offer text.";

def specialist_review(role: Specialist, offer: str, facts: OfferFacts, notes: str) -> list[SoftFlag] by llm(temperature=0.2);
sem specialist_review = "You are a specialist reviewer protecting Sri Lankan migrant workers. Review the offer ONLY from your specialist angle (role). Return 0-4 warning signs. Each evidence MUST be an exact quote from the offer. If nothing is wrong from your angle, return an empty list.";
sem specialist_review.role = "Your specialist angle.";
sem specialist_review.offer = "The raw job offer text.";
sem specialist_review.facts = "Facts the Extractor pulled out.";
sem specialist_review.notes = "The Lead Investigator's findings (register lookup, contacts, community reports, country guidance).";

def prosecute(offer: str, findings: str, flags: list[str]) -> str by llm(temperature=0.3);
sem prosecute = "You are the Prosecutor agent. In at most 5 sentences, argue that this job offer is a scam or dangerous, using only the findings and warning signs given.";

def defend(offer: str, findings: str, flags: list[str]) -> str by llm(temperature=0.3);
sem defend = "You are the Defender agent. In at most 5 sentences, argue the offer may be genuine: point out which warning signs are weak, normal for legitimate recruitment, or not supported by the text. Be honest; do not defend the indefensible (e.g. an unlicensed agency or a tourist visa for work).";

def judge_case(offer: str, findings: str, flags: list[str], prosecution: str, defence: str) -> JudgeRuling by llm(temperature=0.0);
sem judge_case = "You are the Judge agent. Weigh the Prosecutor and Defender. The numbered warning signs are candidates from expert reviewers; dismiss only those the defence clearly rebutted. Official register and rule findings cannot be dismissed.";

def advise(offer: str, band: str, flags: list[str], findings: str) -> Advice by llm(temperature=0.2);
sem advise = "You are the Advisor agent. Give a Sri Lankan job seeker practical next steps for this offer given the verdict band and red flags. Keep language simple.";

# ---------------- helpers ----------------

def _now -> str {
    return datetime.now().strftime("%Y-%m-%d %H:%M");
}

def _clean_name(s: str) -> str {
    return re.sub(r"\b(pvt|ltd|private|limited|\(|\)|\.)\b", " ", s.lower()).replace("(", " ").replace(")", " ").replace(".", " ").split() |> " ".join;
}

def _names_match(a: str, b: str) -> bool {
    x = _clean_name(a);
    y = _clean_name(b);
    if not x or not y {
        return False;
    }
    return x in y or y in x;
}

def _agency_summary(a: AgencyRecord) -> str {
    return f"{a.name} (licence {a.licence_no}, valid until {a.valid_upto}); registered phones: {', '.join(a.phones) or 'none'}; email: {a.email or 'none'}";
}

def _flag_lines(flags: list[RedFlag]) -> list[str] {
    return [f"{i + 1}. [{f.source}] {f.title}: \"{f.evidence}\"" for (i, f) in enumerate(flags)];
}

# ---------------- the investigation walker ----------------

walker:pub Investigate {
    has text: str,
        answers: list[str] = [],
        steps: list[Step] = [],
        facts: OfferFacts | None = None,
        register_status: RegisterStatus = RegisterStatus.NOT_CHECKED,
        agency: AgencyRecord | None = None,
        register_checked_at: str = "",
        register_flags: list[RedFlag] = [],
        community: list[str] = [],
        community_flags: list[RedFlag] = [],
        questions: list[str] = [],
        result: CaseReport | None = None;

    def log(agent: str, action: str, detail: str) {
        self.steps.append(Step(agent=agent, action=action, detail=detail));
    }

    # ----- investigator tools -----

    def lookup_licence(licence_no: str) -> str {
        r = search_by_licence(licence_no);
        self.register_checked_at = r.checked_at;
        if not r.ok {
            self.register_status = RegisterStatus.UNREACHABLE;
            self.log("Lead Investigator", "lookup_licence", f"#{licence_no}: register unreachable");
            return "The SLBFE register could not be reached. Licence status is UNKNOWN; tell the person to call 1989.";
        }
        if not r.records {
            self.register_status = RegisterStatus.NOT_FOUND;
            self.log("Lead Investigator", "lookup_licence", f"#{licence_no}: NOT on the SLBFE register");
            return f"Licence number {licence_no} is NOT on the SLBFE register of valid agencies.";
        }
        rec = r.records[0];
        self.agency = rec;
        claimed = self.facts.agency_name if self.facts is not None else "";
        if claimed and not _names_match(claimed, rec.name) {
            self.register_status = RegisterStatus.NAME_MISMATCH;
            self.log("Lead Investigator", "lookup_licence", f"#{licence_no} belongs to {rec.name}, not '{claimed}'");
            return f"Licence {licence_no} belongs to '{rec.name}', NOT to '{claimed}' named in the offer. {_agency_summary(rec)}";
        }
        self.register_status = RegisterStatus.VERIFIED;
        self.log("Lead Investigator", "lookup_licence", f"#{licence_no} = {rec.name}, valid until {rec.valid_upto}");
        return "Licensed. " + _agency_summary(rec);
    }

    def lookup_agency_name(name: str) -> str {
        r = search_by_name(name);
        self.register_checked_at = r.checked_at;
        if not r.ok {
            self.register_status = RegisterStatus.UNREACHABLE;
            self.log("Lead Investigator", "lookup_agency_name", f"'{name}': register unreachable");
            return "The SLBFE register could not be reached. Licence status is UNKNOWN.";
        }
        hits = [a for a in r.records if _names_match(name, a.name)];
        if not hits {
            if self.register_status != RegisterStatus.VERIFIED {
                self.register_status = RegisterStatus.NOT_FOUND;
            }
            self.log("Lead Investigator", "lookup_agency_name", f"'{name}': no licensed agency with this name ({len(r.records)} partial matches)");
            return f"No licensed agency named '{name}' on the SLBFE register.";
        }
        self.agency = hits[0];
        self.register_status = RegisterStatus.VERIFIED;
        self.log("Lead Investigator", "lookup_agency_name", f"'{name}' = licence {hits[0].licence_no}, valid until {hits[0].valid_upto}");
        return "Licensed. " + _agency_summary(hits[0]);
    }

    def check_contacts -> str {
        if self.agency is None or self.facts is None {
            self.log("Lead Investigator", "check_contacts", "skipped: no verified agency yet");
            return "No verified agency to compare against. Look up the agency first.";
        }
        ag = self.agency;
        offer_phones = [normalise_phone(p) for p in self.facts.phones if normalise_phone(p)];
        offer_emails = [e.lower().strip() for e in self.facts.emails];
        foreign_phones = [p for p in offer_phones if p not in ag.phones];
        foreign_emails = [e for e in offer_emails if e != ag.email];
        if not foreign_phones and not foreign_emails {
            self.log("Lead Investigator", "check_contacts", "all contacts match the agency's registered contacts");
            return "All phone numbers/emails in the offer match the agency's registered contacts.";
        }
        odd = foreign_phones + foreign_emails;
        self.log("Lead Investigator", "check_contacts", f"NOT registered to {ag.name}: {', '.join(odd)}");
        return f"These contacts are NOT registered to {ag.name}: {', '.join(odd)}. Possible impersonation of a licensed agency.";
    }

    def community_reports(contact: str) -> str {
        value = normalise_phone(contact) if re.search(r"\d{9}", re.sub(r"\D", "", contact)) else contact.lower().strip();
        found = [c for c in [root -->[?:Contact]] if c.value == value];
        if not found {
            self.log("Lead Investigator", "community_reports", f"{value}: no earlier reports");
            return f"No earlier checks involve {value}.";
        }
        offers = [o for o in [found[0] <--[?:Offer]]];
        danger = [o for o in offers if o.verdict == "DANGER"];
        line = f"{value} appeared in {len(offers)} earlier checked offer(s); {len(danger)} judged DANGER.";
        self.community.append(line);
        self.log("Lead Investigator", "community_reports", line);
        return line;
    }

    def country_guidance(country: str) -> str {
        note = country_note(country);
        self.log("Lead Investigator", "country_guidance", f"{country}: {note[:90]}...");
        return note;
    }

    def ask_user(question: str) -> str {
        if self.answers {
            return "You already received the person's answers; decide with what you have.";
        }
        if len(self.questions) >= 3 {
            return "Question limit reached.";
        }
        self.questions.append(question);
        self.log("Lead Investigator", "ask_user", question);
        return "Question recorded; the person will be asked. Continue with the other checks.";
    }

    def investigate(offer: str, facts: OfferFacts, answers: list[str]) -> InvestigationNotes by llm(
        tools=[self.lookup_licence, self.lookup_agency_name, self.check_contacts, self.community_reports, self.country_guidance, self.ask_user],
        temperature=0.1,
        max_react_iterations=8
    );

    # ----- deterministic register / community flags -----

    def build_evidence_flags {
        claimed = self.facts.agency_name if self.facts is not None else "";
        if self.register_status == RegisterStatus.NOT_FOUND {
            self.register_flags.append(
                RedFlag(code="NOT_LICENSED", title="Agency is not on the SLBFE register", points=40,
                    evidence=claimed or "no agency named",
                    explanation="Only SLBFE-licensed agencies may recruit for foreign jobs. An unlicensed recruiter is illegal and you have no protection.",
                    source=SRC_REGISTER, agent="Lead Investigator")
            );
        } elif self.register_status == RegisterStatus.NAME_MISMATCH and self.agency is not None {
            self.register_flags.append(
                RedFlag(code="LICENCE_MISMATCH", title="Licence number belongs to a different agency", points=35,
                    evidence=f"Licence {self.agency.licence_no} = {self.agency.name}",
                    explanation="Scammers often print a real licence number that belongs to another company.",
                    source=SRC_REGISTER, agent="Lead Investigator")
            );
        }
        if self.agency is not None and self.facts is not None {
            ag = self.agency;
            odd = [p for p in [normalise_phone(x) for x in self.facts.phones] if p and p not in ag.phones];
            odd_mail = [e.lower().strip() for e in self.facts.emails if e.lower().strip() != ag.email];
            if odd or odd_mail {
                self.register_flags.append(
                    RedFlag(code="IMPERSONATION", title="Contact details not registered to this agency", points=30,
                        evidence=", ".join(odd + odd_mail),
                        explanation=f"{ag.name} is licensed, but these contacts are not its registered ones ({', '.join(ag.phones)}). Someone may be using a real agency's name. Call the agency on its registered number.",
                        source=SRC_REGISTER, agent="Lead Investigator")
                );
            }
        }
        for line in self.community {
            if "judged DANGER" in line and not line.endswith("; 0 judged DANGER.") {
                self.community_flags.append(
                    RedFlag(code="COMMUNITY", title="Contact linked to earlier dangerous offers", points=20,
                        evidence=line, explanation="Other people checked offers using the same contact, and they were judged dangerous.",
                        source=SRC_COMMUNITY, agent="Lead Investigator")
                );
            }
        }
    }

    def ensure_register_checked {
        if self.facts is None {
            return;
        }
        if self.register_status == RegisterStatus.NOT_CHECKED {
            if self.facts.licence_no {
                self.log("Supervisor", "enforce_check", "investigator skipped the register; checking licence number");
                self.lookup_licence(self.facts.licence_no);
            } elif self.facts.agency_name {
                self.log("Supervisor", "enforce_check", "investigator skipped the register; checking agency name");
                self.lookup_agency_name(self.facts.agency_name);
            } else {
                self.register_status = RegisterStatus.NOT_FOUND;
                self.log("Supervisor", "enforce_check", "no agency or licence named in the offer");
            }
        }
        for p in self.facts.phones {
            v = normalise_phone(p);
            if v and not any([v in c for c in self.community]) {
                self.community_reports(p);
            }
        }
    }

    # ----- persistence + network alerts -----

    def save_case(band: str, score: int, summary: str) -> tuple[str, int] {
        f = self.facts;
        if f is None {
            return ("", 0);
        }
        offer = Offer(text=self.text, job=f.job_title, country=f.country, agency_name=f.agency_name,
            verdict=band.replace(" ", "_").replace("LOOKS_SAFE", "SAFE").replace("BE_CAREFUL", "CAREFUL"),
            score=score, summary=summary, created_at=_now());
        root ++> offer;
        if self.agency is not None {
            ag = self.agency;
            existing = [a for a in [root -->[?:Agency]] if a.licence_no == ag.licence_no];
            node_ag = existing[0] if existing else Agency(licence_no=ag.licence_no, name=ag.name, phones=ag.phones, email=ag.email, valid_upto=ag.valid_upto, checked_at=self.register_checked_at);
            if not existing {
                root ++> node_ag;
            }
            offer ++> node_ag;
        }
        values = [(normalise_phone(p), "phone") for p in f.phones if normalise_phone(p)] + [(e.lower().strip(), "email") for e in f.emails if e.strip()];
        alerts = 0;
        for (v, kind) in values {
            found = [c for c in [root -->[?:Contact]] if c.value == v];
            c = found[0] if found else Contact(value=v, kind=kind);
            if not found {
                root ++> c;
            }
            if offer.verdict == "DANGER" {
                for other in [c <--[?:Offer]] {
                    if other.verdict != "DANGER" {
                        other ++> Alert(message=f"The contact {v} from an offer you checked was later linked to a DANGER offer ({f.job_title} in {f.country}).", created_at=_now());
                        alerts += 1;
                    }
                }
            }
            offer ++> c;
        }
        if alerts {
            self.log("Network Guardian", "alert_walk", f"warned {alerts} earlier check(s) that share a contact with this offer");
        }
        return (jid(offer), alerts);
    }

    # ----- orchestration -----

    can run with Root entry {
        self.log("Supervisor", "start", f"new case, {len(self.text)} characters" + (f", {len(self.answers)} answers from the person" if self.answers else ""));
        facts = extract_facts(self.text + ("\n\nExtra answers from the person:\n" + "\n".join(self.answers) if self.answers else ""));
        self.facts = facts;
        self.log("Extractor", "extract_facts", f"{facts.job_title or '?'} in {facts.country or '?'}; agency '{facts.agency_name or 'none'}'; licence '{facts.licence_no or 'none'}'; visa '{facts.visa_type or 'not stated'}'; {len(facts.phones)} phone(s), {len(facts.fees)} fee(s)");

        notes = self.investigate(self.text, facts, self.answers);
        self.log("Lead Investigator", "findings", notes.summary);
        self.ensure_register_checked();

        if self.questions and not self.answers {
            self.log("Supervisor", "pause", f"needs {len(self.questions)} answer(s) from the person before the verdict");
            self.result = CaseReport(status="needs_input", questions=self.questions, steps=self.steps, facts=facts,
                agency=self.agency, register_status=self.register_status.name);
            report self.result;
            disengage;
        }

        self.build_evidence_flags();
        findings = notes.summary + " " + " ".join(self.community);

        experts = notes.specialists or [Specialist.FEES];
        self.log("Supervisor", "route", "calling " + ", ".join([e.name.title() + " expert" for e in experts]));
        soft: list[RedFlag] = [];
        with ThreadPoolExecutor(max_workers=3) as pool {
            futs = [pool.submit(specialist_review, e, self.text, facts, findings) for e in experts];
            reviews = [f.result() for f in futs];
        }
        for (i, e) in enumerate(experts) {
            res = reviews[i];
            name = e.name.title() + " expert";
            self.log(name, "review", f"{len(res)} warning sign(s)" + (": " + "; ".join([s.title for s in res]) if res else ""));
            soft.extend([soft_to_red(s, name) for s in res]);
        }

        hard = self.register_flags + self.community_flags + rule_flags(facts);
        candidates = dedupe(hard + soft);
        (kept, removed) = critic(candidates, self.text + "\n" + "\n".join(self.answers));
        for r in removed {
            self.log("Critic", "removed", r);
        }

        lines = _flag_lines(kept);
        with ThreadPoolExecutor(max_workers=2) as pool {
            pf = pool.submit(prosecute, self.text, findings, lines);
            df = pool.submit(defend, self.text, findings, lines);
            prosecution: str = pf.result();
            defence: str = df.result();
        }
        self.log("Prosecutor", "argue", prosecution[:160]);
        self.log("Defender", "argue", defence[:160]);
        ruling = judge_case(self.text, findings, lines, prosecution, defence);
        final: list[RedFlag] = [];
        for (i, f) in enumerate(kept) {
            if (i + 1) in ruling.dismissed and f.source not in [SRC_REGISTER, SRC_COMMUNITY, SRC_GUIDANCE] {
                self.log("Judge", "dismissed", f.title);
            } else {
                final.append(f);
            }
        }
        sc = score_flags(final);
        self.log("Judge", "verdict", f"{sc.band} ({sc.total}/100): {ruling.summary[:140]}");

        advice = advise(self.text, sc.band, _flag_lines(final), findings);
        self.log("Advisor", "advise", f"{len(advice.questions_to_ask)} questions, {len(advice.next_steps)} next steps");

        (offer_id, alerts) = self.save_case(sc.band, sc.total, ruling.summary);

        sources = [Source(name=SRC_GUIDANCE, detail=GENERAL_GUIDANCE, url="https://www.slbfe.lk")];
        if self.register_status != RegisterStatus.NOT_CHECKED {
            sources.insert(0, Source(name=SRC_REGISTER, detail=f"status {self.register_status.name}, checked {self.register_checked_at}", url="https://applications.slbfe.lk/feb/la/la_main.asp"));
        }
        if self.community {
            sources.append(Source(name=SRC_COMMUNITY, detail=" ".join(self.community)));
        }
        self.result = CaseReport(status="done", band=sc.band, score=sc.total, hard_points=sc.hard_points, soft_points=sc.soft_points,
            flags=final, removed=removed, prosecution=prosecution, defence=defence, judge=ruling.summary, advice=advice,
            agency=self.agency, register_status=self.register_status.name, community=self.community, alerts_sent=alerts,
            facts=facts, sources=sources, steps=self.steps, offer_id=offer_id);
        report self.result;
    }
}

sem Investigate.investigate = "You are the Lead Investigator protecting a Sri Lankan job seeker. Decide your own investigation: use the tools to verify the agency on the live SLBFE register (by licence number if printed, else by name), check whether the offer's contacts belong to that agency, check community reports for each phone number, and read the destination country's guidance. If a decisive fact is missing (e.g. visa type, whether money is asked before a contract), call ask_user with one short question (max 2 questions). Then summarise findings and pick the specialist reviewers.";
sem Investigate.investigate.offer = "The raw job offer text.";
sem Investigate.investigate.facts = "Facts from the Extractor.";
sem Investigate.investigate.answers = "Answers the person already gave to earlier questions (may be empty).";
sem Investigate.lookup_licence = "Look up an SLBFE licence number on the live official register. Returns the licensed agency, its registered phones/email and expiry, or says it is not registered.";
sem Investigate.lookup_licence.licence_no = "Licence number printed in the offer (digits).";
sem Investigate.lookup_agency_name = "Search the live official SLBFE register by agency name.";
sem Investigate.lookup_agency_name.name = "Agency name as written in the offer.";
sem Investigate.check_contacts = "Compare the offer's phone numbers and emails with the verified agency's registered contacts, to detect impersonation. Call after a successful lookup.";
sem Investigate.community_reports = "Check whether a phone number or email appeared in offers other people checked before, and how they were judged.";
sem Investigate.community_reports.contact = "A phone number or email from the offer.";
sem Investigate.country_guidance = "Read official guidance and known scam patterns for the destination country.";
sem Investigate.country_guidance.country = "Destination country name in English.";
sem Investigate.ask_user = "Ask the job seeker one short, simple question about a decisive missing fact. Use sparingly.";
sem Investigate.ask_user.question = "The question, in simple English.";

obj CheckView {
    has id: str,
        job: str,
        country: str,
        agency: str,
        verdict: str,
        score: int,
        created_at: str,
        alerts: list[str];
}

walker:pub RecentChecks {
    has limit: int = 10;

    can list with Root entry {
        offers = [root -->[?:Offer]];
        offers = offers[-self.limit:];
        offers.reverse();
        for o in offers {
            report CheckView(id=jid(o), job=o.job, country=o.country, agency=o.agency_name, verdict=o.verdict,
                score=o.score, created_at=o.created_at, alerts=[a.message for a in [o -->[?:Alert]]]);
        }
    }
}
