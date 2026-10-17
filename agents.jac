"""The agent team: Extractor -> Lead Investigator (ReAct, own tool choices, may ask the
person) -> chosen Specialists -> Prosecutor vs Defender -> Judge -> Critic -> Scorer -> Advisor.
Every action is logged to `steps` so the UI can show the investigation live.
"""
import re;
import from concurrent.futures { ThreadPoolExecutor }
import from datetime { datetime }
import from models { llm }
import from graph { Agency, Contact, Offer, Alert }
import from rules {
    RedFlag, Score, RegisterStatus,
    SRC_REGISTER, SRC_AGENT, SRC_COMMUNITY, SRC_GUIDANCE, GENERAL_GUIDANCE,
    country_note, critic, dedupe, score_flags,
    find_phones, find_emails, find_licence, find_visa_word, redact_pii,
    SRC_SALARY, to_lkr, salary_flag, licence_expiry_flag, text_similarity
}
import from slbfe { AgencyRecord, RegisterResult, search_by_licence, search_by_name, normalise_phone }

# ---------- objects the agents fill in (LLM schemas) ----------
# jac 0.34: by-llm return types must live in the same module as the by-llm functions.

obj Fee {
    has label: str,
        amount: float,
        currency: str,
        evidence: str;
}

obj OfferFacts {
    has job_title: str = "",
        country: str = "",
        salary_amount: float = 0.0,
        salary_currency: str = "",
        agency_name: str = "",
        licence_no: str = "",
        visa_type: str = "",
        phones: list[str] = [],
        emails: list[str] = [],
        fees: list[Fee] = [],
        payment_to_personal_account: bool = False,
        payment_evidence: str = "",
        pay_before_contract: bool = False,
        pay_before_contract_evidence: str = "",
        passport_retained: bool = False,
        passport_evidence: str = "",
        visa_evidence: str = "";
}

sem OfferFacts.job_title = "Job title offered, e.g. 'House driver', 'Data entry', 'Caregiver'.";
sem OfferFacts.country = "Destination country in English, e.g. 'Qatar', 'Thailand'. Empty if not stated.";
sem OfferFacts.salary_amount = "Monthly salary number as stated (0 if not stated).";
sem OfferFacts.salary_currency = "Currency code of the salary, e.g. USD, QAR, AED, SAR, LKR.";
sem OfferFacts.agency_name = "Name of the Sri Lankan recruitment agency named in the offer, empty if none.";
sem OfferFacts.licence_no = "SLBFE licence number if the offer prints one (digits only), else empty.";
sem OfferFacts.visa_type = "Visa type stated: 'work', 'employment', 'visit', 'tourist', 'student', or empty if not stated.";
sem OfferFacts.phones = "All phone / WhatsApp numbers in the offer, as written.";
sem OfferFacts.emails = "All email addresses in the offer.";
sem OfferFacts.fees = "Every amount the WORKER is asked to pay (registration, processing, visa, medical, ticket...).";
sem OfferFacts.payment_to_personal_account = "True if the worker is told to pay into a personal bank account, eZ Cash, or to an individual rather than the agency's company account.";
sem OfferFacts.pay_before_contract = "True if money is demanded before the worker receives/signs a written employment contract or before visa approval.";
sem OfferFacts.passport_retained = "True if the employer/agency will keep the worker's passport.";
sem Fee.evidence = "Exact quote from the offer showing this fee.";

enum Severity { CRITICAL, HIGH, MEDIUM, LOW }

obj SoftFlag {
    has title: str,
        evidence: str,
        explanation: str,
        severity: Severity;
}

sem SoftFlag.title = "Short name of the warning sign, e.g. 'Pressure to pay quickly'.";
sem SoftFlag.evidence = "EXACT words copied from the offer that show the problem (verbatim quote, max ~20 words). Never paraphrase.";
sem SoftFlag.explanation = "One or two plain-language sentences for a worker with basic English: why this is risky.";

enum Specialist { TRAFFICKING, CONTRACT, FEES }

sem Specialist.TRAFFICKING = "Human trafficking / scam-compound / war recruitment patterns (e.g. IT or data-entry jobs in Thailand/Myanmar/Cambodia/Laos, tourist visa, flights paid, Russia army jobs).";
sem Specialist.CONTRACT = "Contract and working-condition clauses (passport retention, hours, deductions, job mismatch, salary vagueness).";
sem Specialist.FEES = "Money: fees, payment method, payment timing, unrealistic salary.";

obj InvestigationNotes {
    has summary: str,
        specialists: list[Specialist];
}

sem InvestigationNotes.summary = "Investigator's findings so far in 3-6 short sentences, citing the tool results (register, contacts, community, country guidance).";
sem InvestigationNotes.specialists = "Which expert reviewers should examine this offer next. Pick only the relevant ones (1-3).";

obj JudgeRuling {
    has summary: str,
        dismissed: list[int];
}

sem JudgeRuling.summary = "Two or three sentences: the judge's overall conclusion after hearing both sides.";
sem JudgeRuling.dismissed = "Numbers of the candidate warning signs that the defence successfully rebutted and should be dropped. Empty if all stand.";

obj Advice {
    has questions_to_ask: list[str],
        next_steps: list[str],
        report_draft: str;
}

sem Advice.questions_to_ask = "3-5 specific questions the worker should ask the agency before paying anything.";
sem Advice.next_steps = "3-5 concrete actions, e.g. verify licence on slbfe.lk, call the SLBFE 1989 hotline, never hand over passport, insist on receipts.";
sem Advice.report_draft = "A short complaint the worker can send to the SLBFE (1989 hotline / slbfe.lk) describing the offer and its red flags. Empty if the offer looks safe.";

# ---------- official-rule flags over the extracted facts ----------

"""Hard flags that come from official rules applied to the extracted facts."""
def rule_flags(facts: OfferFacts) -> list[RedFlag] {
    flags: list[RedFlag] = [];
    visa = facts.visa_type.lower();
    if "visit" in visa or "tourist" in visa or "arrival" in visa or "permit" in visa or "pass" in visa {
        flags.append(
            RedFlag(
                code="VISIT_VISA",
                title="Job offered on a visit/tourist visa",
                points=30,
                evidence=facts.visa_evidence or facts.visa_type,
                explanation="You cannot legally work on a visit or tourist visa. You will have no labour rights, no SLBFE insurance, and can be arrested or stranded.",
                source=SRC_GUIDANCE,
                agent="Rules engine"
            )
        );
    }
    if facts.payment_to_personal_account {
        flags.append(
            RedFlag(
                code="PERSONAL_ACCOUNT",
                title="Payment to a personal account",
                points=25,
                evidence=facts.payment_evidence,
                explanation="Licensed agencies issue official receipts from a company account. Paying an individual leaves you with no proof and no way to recover your money.",
                source=SRC_GUIDANCE,
                agent="Rules engine"
            )
        );
    }
    if facts.pay_before_contract {
        flags.append(
            RedFlag(
                code="PAY_BEFORE_CONTRACT",
                title="Money demanded before a contract",
                points=25,
                evidence=facts.pay_before_contract_evidence,
                explanation="SLBFE advises never to pay before you have verified the agency and seen a written job offer/contract.",
                source=SRC_GUIDANCE,
                agent="Rules engine"
            )
        );
    }
    if facts.passport_retained {
        flags.append(
            RedFlag(
                code="PASSPORT",
                title="Employer or agent keeps your passport",
                points=25,
                evidence=facts.passport_evidence,
                explanation="Holding a worker's passport is a common sign of forced labour. Your passport must stay with you.",
                source=SRC_GUIDANCE,
                agent="Rules engine"
            )
        );
    }
    return flags;
}

def severity_points(sev: Severity) -> int {
    if sev == Severity.CRITICAL {
        return 10;
    }
    if sev == Severity.HIGH {
        return 8;
    }
    if sev == Severity.MEDIUM {
        return 5;
    }
    return 3;
}

def soft_to_red(s: SoftFlag, agent: str) -> RedFlag {
    return RedFlag(
        code="AGENT",
        title=s.title,
        points=severity_points(s.severity),
        evidence=s.evidence,
        explanation=s.explanation,
        source=SRC_AGENT,
        agent=agent
    );
}

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
        confidence: int = 0,
        offer_id: str = "";
}

# ---------------- LLM agents (plain functions) ----------------

def extract_facts(offer: str) -> OfferFacts by llm(temperature=0.0);
sem extract_facts = "You are the Extractor agent. Read a foreign job offer (Facebook ad, WhatsApp message or contract) aimed at Sri Lankan workers and extract the facts. Do not invent anything that is not in the text. Copy every evidence string VERBATIM from the offer text (a short exact quote), or leave it empty.";
sem extract_facts.offer = "The raw job offer text.";

def specialist_review(today: str, role: Specialist, offer: str, facts: OfferFacts, notes: str) -> list[SoftFlag] by llm(temperature=0.2);
sem specialist_review = "You are a specialist reviewer protecting Sri Lankan migrant workers. Review the offer ONLY from your specialist angle (role). Return 0-4 warning signs. Each evidence MUST be an exact quote from the offer. If nothing is wrong from your angle, return an empty list.";
sem specialist_review.today = "Today's date (YYYY-MM-DD); dates before it are in the past.";
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

glob NAME_STOPWORDS: list[str] = ["pvt", "ltd", "private", "limited", "company", "co", "the", "and", "agency", "agencies", "recruitment", "recruiters", "foreign", "employment", "manpower", "services", "lanka", "sri"];

def _name_tokens(s: str) -> list[str] {
    words = re.sub(r"[^a-z0-9 ]+", " ", s.lower()).split();
    return [w for w in words if w not in NAME_STOPWORDS];
}

"""Agency names match if their letters agree ignoring spacing/suffixes (A T C GLOBAL = ATC Global),
or most of their distinctive words overlap."""
def _names_match(a: str, b: str) -> bool {
    ta = _name_tokens(a);
    tb = _name_tokens(b);
    if not ta or not tb {
        return False;
    }
    ja = "".join(ta);
    jb = "".join(tb);
    short = ja if len(ja) <= len(jb) else jb;
    long = jb if len(ja) <= len(jb) else ja;
    if ja == jb or (len(short) >= 6 and short in long and len(short) / len(long) >= 0.5) {
        return True;
    }
    common = len(set(ta) & set(tb));
    return common / max(len(set(ta)), len(set(tb))) >= 0.6;
}

"""Most distinctive word of a name, used as the register's 'any part of name' query."""
def _search_word(name: str) -> str {
    toks = sorted(_name_tokens(name), key=lambda (t: str) { -len(t); });
    return toks[0] if toks else name;
}

def _norm_text(s: str) -> str {
    return re.sub(r"[^a-z0-9]+", " ", s.lower()).strip();
}

def _record_from_node(a: Agency) -> AgencyRecord {
    return AgencyRecord(licence_no=a.licence_no, name=a.name, phones=a.phones, email=a.email, valid_upto=a.valid_upto);
}

def _agency_summary(a: AgencyRecord) -> str {
    return f"{a.name} (licence {a.licence_no}, valid until {a.valid_upto}); registered phones: {', '.join(a.phones) or 'none'}; email: {a.email or 'none'}";
}

"""Confidence (0-100) in the verdict: how many key facts were found, whether the register answered live, and how many agents failed."""
def _confidence(facts: OfferFacts, register_live: bool, failures: int) -> int {
    known = len([x for x in [facts.job_title, facts.country, facts.visa_type, facts.licence_no or facts.agency_name] if x]);
    known += 1 if facts.salary_amount > 0 else 0;
    known += 1 if facts.phones else 0;
    score = 35 + known * 8 + (12 if register_live else 0) - failures * 12;
    return max(20, min(95, score));
}

def _flag_lines(flags: list[RedFlag]) -> list[str] {
    return [f"{i + 1}. [{f.source}] {f.title}: \"{f.evidence}\"" for (i, f) in enumerate(flags)];
}

# ---------------- the investigation walker ----------------

"""Internal case state (kept out of the walker's request schema)."""
obj CaseState {
    has facts: OfferFacts | None = None,
        agency: AgencyRecord | None = None,
        result: CaseReport | None = None;
}

walker:pub Investigate {
    has text: str,
        answers: list[str] = [],
        steps: list[Step] = [],
        register_status: RegisterStatus = RegisterStatus.NOT_CHECKED,
        register_checked_at: str = "",
        register_flags: list[RedFlag] = [],
        community: list[str] = [],
        community_flags: list[RedFlag] = [],
        questions: list[str] = [],
        licence_not_found: bool = False,
        repost_flags: list[RedFlag] = [],
        quiet: bool = False;
    has st: CaseState postinit;

    def postinit {
        self.st = CaseState();
    }

    def log(agent: str, action: str, detail: str) {
        self.steps.append(Step(agent=agent, action=action, detail=detail));
    }

    # ----- investigator tools -----

    def lookup_licence(licence_no: str) -> str {
        r = search_by_licence(licence_no);
        self.register_checked_at = r.checked_at;
        if not r.ok {
            digits = re.sub(r"\D", "", licence_no);
            cached = [a for a in [root -->[?:Agency]] if a.licence_no == digits];
            if not cached {
                self.register_status = RegisterStatus.UNREACHABLE;
                self.log("Lead Investigator", "lookup_licence", f"#{licence_no}: register unreachable and no cached copy");
                return "The SLBFE register could not be reached. Licence status is UNKNOWN; tell the person to call 1989.";
            }
            r.records = [_record_from_node(cached[0])];
            self.register_checked_at = f"cached copy from {cached[0].checked_at} (live register unreachable)";
            self.log("Lead Investigator", "lookup_licence", f"#{licence_no}: live register unreachable; using cached register copy from {cached[0].checked_at}");
        }
        if not r.records {
            self.register_status = RegisterStatus.NOT_FOUND;
            self.licence_not_found = True;
            self.log("Lead Investigator", "lookup_licence", f"#{licence_no}: NOT on the SLBFE register");
            return f"Licence number {licence_no} is NOT on the SLBFE register of valid agencies.";
        }
        rec = r.records[0];
        self.st.agency = rec;
        claimed = self.st.facts.agency_name if self.st.facts is not None else "";
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
        r = search_by_name(_search_word(name));
        self.register_checked_at = r.checked_at;
        if not r.ok {
            cached = [a for a in [root -->[?:Agency]] if _names_match(name, a.name)];
            if not cached {
                self.register_status = RegisterStatus.UNREACHABLE;
                self.log("Lead Investigator", "lookup_agency_name", f"'{name}': register unreachable and no cached copy");
                return "The SLBFE register could not be reached. Licence status is UNKNOWN.";
            }
            r.records = [_record_from_node(a) for a in cached];
            self.register_checked_at = f"cached copy from {cached[0].checked_at} (live register unreachable)";
            self.log("Lead Investigator", "lookup_agency_name", f"'{name}': live register unreachable; using cached register copy from {cached[0].checked_at}");
        }
        hits = [a for a in r.records if _names_match(name, a.name)];
        if not hits {
            if self.register_status != RegisterStatus.VERIFIED {
                self.register_status = RegisterStatus.NOT_FOUND;
            }
            self.log("Lead Investigator", "lookup_agency_name", f"'{name}': no licensed agency with this name ({len(r.records)} partial matches)");
            return f"No licensed agency named '{name}' on the SLBFE register.";
        }
        if self.register_status == RegisterStatus.NAME_MISMATCH {
            self.log("Lead Investigator", "lookup_agency_name", f"'{name}' is licensed as {hits[0].licence_no}, but the printed licence number belongs to another agency");
            return f"'{name}' is a licensed agency (licence {hits[0].licence_no}), but the licence number printed in the offer belongs to a different agency.";
        }
        self.st.agency = hits[0];
        if self.licence_not_found {
            self.register_status = RegisterStatus.NAME_MISMATCH;
            self.log("Lead Investigator", "lookup_agency_name", f"'{name}' is licensed as {hits[0].licence_no}, but the licence number printed in the offer does not exist");
            return f"'{name}' is licensed under licence {hits[0].licence_no}, but the licence number printed in the offer is NOT on the register. " + _agency_summary(hits[0]);
        }
        self.register_status = RegisterStatus.VERIFIED;
        self.log("Lead Investigator", "lookup_agency_name", f"'{name}' = licence {hits[0].licence_no}, valid until {hits[0].valid_upto}");
        return "Licensed. " + _agency_summary(hits[0]);
    }

    def check_contacts -> str {
        if self.st.agency is None or self.st.facts is None {
            self.log("Lead Investigator", "check_contacts", "skipped: no verified agency yet");
            return "No verified agency to compare against. Look up the agency first.";
        }
        ag = self.st.agency;
        fphones: list[str] = self.st.facts.phones;
        femails: list[str] = self.st.facts.emails;
        offer_phones = [normalise_phone(p) for p in fphones if normalise_phone(p)];
        offer_emails = [e.lower().strip() for e in femails];
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
        mine = _norm_text(self.text);
        offers = [o for o in [found[0] <--[?:Offer]] if _norm_text(o.text) != mine];
        if not offers {
            self.log("Lead Investigator", "community_reports", f"{value}: only earlier checks of this same offer");
            return f"No other offers involve {value}.";
        }
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

    def salary_in_lkr(amount: float, currency: str) -> str {
        lkr = to_lkr(amount, currency);
        if lkr < 0 {
            self.log("Lead Investigator", "salary_in_lkr", f"{amount} {currency}: unknown currency");
            return f"Unknown currency {currency}.";
        }
        self.log("Lead Investigator", "salary_in_lkr", f"{amount:,.0f} {currency} = about Rs. {lkr:,.0f} per month");
        return f"{amount:,.0f} {currency} is about Rs. {lkr:,.0f} per month (approximate fixed rate).";
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
        tools=[self.lookup_licence, self.lookup_agency_name, self.check_contacts, self.community_reports, self.country_guidance, self.salary_in_lkr, self.ask_user],
        temperature=0.1,
        max_react_iterations=8
    );

    # ----- deterministic register / community flags -----

    def build_evidence_flags {
        claimed = self.st.facts.agency_name if self.st.facts is not None else "";
        if self.register_status == RegisterStatus.NOT_FOUND {
            self.register_flags.append(
                RedFlag(code="NOT_LICENSED", title="Agency is not on the SLBFE register", points=40,
                    evidence=claimed or "No agency name or SLBFE licence number given",
                    explanation="Only SLBFE-licensed agencies may recruit for foreign jobs. An unlicensed recruiter is illegal and you have no protection.",
                    source=SRC_REGISTER, agent="Lead Investigator")
            );
        } elif self.register_status == RegisterStatus.NAME_MISMATCH and self.st.agency is not None {
            self.register_flags.append(
                RedFlag(code="LICENCE_MISMATCH", title="Printed licence number does not match the agency", points=35,
                    evidence=f"Offer prints licence {self.st.facts.licence_no if self.st.facts is not None else '?'}; register: {self.st.agency.name} = licence {self.st.agency.licence_no}",
                    explanation="Scammers often print a real licence number that belongs to another company.",
                    source=SRC_REGISTER, agent="Lead Investigator")
            );
        }
        if self.st.agency is not None and self.register_status == RegisterStatus.VERIFIED {
            exp = licence_expiry_flag(self.st.agency.valid_upto, self.st.agency.name, datetime.now().strftime("%Y-%m-%d"));
            for f in exp {
                self.log("Supervisor", "licence_expiry", f.evidence);
            }
            self.register_flags.extend(exp);
        }
        if self.st.agency is not None and self.st.facts is not None and self.register_status == RegisterStatus.VERIFIED {
            ag = self.st.agency;
            odd = [p for p in [normalise_phone(x) for x in self.st.facts.phones] if p and p not in ag.phones];
            odd_mail = [e.lower().strip() for e in self.st.facts.emails if e.lower().strip() != ag.email];
            if odd or odd_mail {
                self.register_flags.append(
                    RedFlag(code="IMPERSONATION", title="Contact details not registered to this agency", points=30,
                        evidence=", ".join(odd + odd_mail),
                        explanation=f"{ag.name} is licensed, but these contacts are not its registered ones ({', '.join(ag.phones)}). Someone may be using a real agency's name. Call the agency on its registered number.",
                        source=SRC_REGISTER, agent="Lead Investigator")
                );
            }
        }
        official: list[str] = self.st.agency.phones if (self.st.agency is not None and self.register_status == RegisterStatus.VERIFIED) else [];
        for line in self.community {
            if any([line.startswith(p + " ") for p in official]) {
                continue;
            }
            if "judged DANGER" in line and not line.endswith("; 0 judged DANGER.") {
                self.community_flags.append(
                    RedFlag(code="COMMUNITY", title="Contact linked to earlier dangerous offers", points=20,
                        evidence=line, explanation="Other people checked offers using the same contact, and they were judged dangerous.",
                        source=SRC_COMMUNITY, agent="Lead Investigator")
                );
            }
        }
    }

    # ----- supervisor double-checks the Extractor with plain patterns -----

    def cross_check(facts: OfferFacts) -> OfferFacts {
        source = self.text + "\n" + "\n".join(self.answers);
        notes: list[str] = [];
        fphones: list[str] = facts.phones;
        known = [normalise_phone(p) for p in fphones];
        for p in find_phones(source) {
            if normalise_phone(p) not in known and p not in known {
                facts.phones = facts.phones + [p];
                known.append(normalise_phone(p));
                notes.append(f"added missed phone {p}");
            }
        }
        femails: list[str] = facts.emails;
        known_mail = [e.lower().strip() for e in femails];
        for e in find_emails(source) {
            if e not in known_mail {
                facts.emails = facts.emails + [e];
                notes.append(f"added missed email {e}");
            }
        }
        lic = find_licence(self.text);
        extracted = re.sub(r"\D", "", facts.licence_no);
        if lic and extracted != lic {
            notes.append(f"licence number corrected from '{facts.licence_no}' to '{lic}' (as printed)" if extracted else f"added missed licence number {lic}");
            facts.licence_no = lic;
        }
        if not facts.visa_type {
            v = find_visa_word(source);
            if v {
                facts.visa_type = v;
                facts.visa_evidence = v;
                notes.append(f"added visa type '{v}' found in the text");
            }
        }
        if notes {
            self.log("Supervisor", "cross_check", "Extractor output corrected: " + "; ".join(notes));
        } else {
            self.log("Supervisor", "cross_check", "Extractor output confirmed by pattern check (phones, emails, licence, visa)");
        }
        return facts;
    }

    # ----- duplicate-offer detector: same wording, different numbers (graph walk over earlier offers) -----

    def find_reposts {
        fx = self.st.facts;
        if fx is None {
            return;
        }
        official: list[str] = self.st.agency.phones if (self.st.agency is not None and self.register_status == RegisterStatus.VERIFIED) else [];
        fphones: list[str] = fx.phones;
        mine_contacts = set([normalise_phone(p) for p in fphones if normalise_phone(p) and normalise_phone(p) not in official]);
        mine = _norm_text(self.text);
        for o in [root -->[?:Offer]] {
            if _norm_text(o.text) == mine {
                continue;
            }
            sim = text_similarity(self.text, o.text);
            if sim < 0.8 {
                continue;
            }
            theirs = set([c.value for c in [o -->[?:Contact]]]);
            if theirs == mine_contacts {
                continue;
            }
            line = f"{int(sim * 100)}% same wording as an offer checked on {o.created_at} (verdict {o.verdict or 'n/a'}) that used {', '.join(sorted(theirs)) or 'only registered numbers'}";
            self.log("Duplicate Detector", "repost", line);
            self.repost_flags.append(
                RedFlag(code="REPOST", title="Same ad reposted with different contact numbers", points=20, evidence=line,
                    explanation="Scammers copy a real or earlier ad and swap in their own phone numbers. Contact the agency only on its registered numbers from the SLBFE register.",
                    source=SRC_COMMUNITY, agent="Duplicate Detector")
            );
            return;
        }
        self.log("Duplicate Detector", "repost", "no earlier ad with the same wording but different numbers");
    }

    def ensure_register_checked {
        if self.st.facts is None {
            return;
        }
        if self.register_status == RegisterStatus.NOT_CHECKED {
            if self.st.facts.licence_no {
                self.log("Supervisor", "enforce_check", "investigator skipped the register; checking licence number");
                self.lookup_licence(self.st.facts.licence_no);
            } elif self.st.facts.agency_name {
                self.log("Supervisor", "enforce_check", "investigator skipped the register; checking agency name");
                self.lookup_agency_name(self.st.facts.agency_name);
            } else {
                self.register_status = RegisterStatus.NOT_FOUND;
                self.log("Supervisor", "enforce_check", "no agency or licence named in the offer");
            }
        }
        for p in self.st.facts.phones {
            v = normalise_phone(p);
            if v and not any([v in c for c in self.community]) {
                self.community_reports(p);
            }
        }
    }

    # ----- persistence + network alerts -----

    def save_case(band: str, score: int, summary: str) -> tuple[str, int] {
        f = self.st.facts;
        if f is None {
            return ("", 0);
        }
        clean_text = redact_pii(self.text);
        offer = Offer(text=clean_text[:500], job=f.job_title, country=f.country, agency_name=f.agency_name,
            verdict=band.replace(" ", "_").replace("LOOKS_SAFE", "SAFE").replace("BE_CAREFUL", "CAREFUL"),
            score=score, summary=summary, created_at=_now());
        root ++> offer;
        if self.st.agency is not None {
            ag = self.st.agency;
            existing = [a for a in [root -->[?:Agency]] if a.licence_no == ag.licence_no];
            node_ag = existing[0] if existing else Agency(licence_no=ag.licence_no, name=ag.name, phones=ag.phones, email=ag.email, valid_upto=ag.valid_upto, checked_at=self.register_checked_at);
            if not existing {
                root ++> node_ag;
            }
            offer ++> node_ag;
        }
        official: list[str] = [];
        if self.st.agency is not None {
            official = self.st.agency.phones + [self.st.agency.email];
        }
        fphones: list[str] = f.phones;
        femails: list[str] = f.emails;
        values: list[tuple[str, str]] = [(normalise_phone(p), "phone") for p in fphones if normalise_phone(p) and normalise_phone(p) not in official]
            + [(e.lower().strip(), "email") for e in femails if e.strip() and e.lower().strip() not in official];
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
        facts = OfferFacts();
        try {
            facts = extract_facts(self.text + ("\n\nExtra answers from the person:\n" + "\n".join(self.answers) if self.answers else ""));
        } except Exception as e {
            self.log("Supervisor", "agent_failed", f"Extractor unavailable ({type(e).__name__}); falling back to pattern extraction only");
        }
        self.log("Extractor", "extract_facts", f"{facts.job_title or '?'} in {facts.country or '?'}; agency '{facts.agency_name or 'none'}'; licence '{facts.licence_no or 'none'}'; visa '{facts.visa_type or 'not stated'}'; {len(facts.phones)} phone(s), {len(facts.fees)} fee(s)");
        facts = self.cross_check(facts);
        self.st.facts = facts;

        notes = InvestigationNotes(summary="", specialists=[]);
        try {
            notes = self.investigate(self.text, facts, self.answers);
        } except Exception as e {
            self.log("Supervisor", "agent_failed", f"Lead Investigator unavailable ({type(e).__name__}); Supervisor runs the register, contact and community checks directly");
            notes = InvestigationNotes(summary="The Supervisor ran the checks directly because the Lead Investigator was unavailable.", specialists=[Specialist.TRAFFICKING, Specialist.CONTRACT, Specialist.FEES]);
        }
        self.log("Lead Investigator", "findings", notes.summary);
        self.ensure_register_checked();
        self.find_reposts();

        if self.questions and not self.answers {
            self.log("Supervisor", "pause", f"needs {len(self.questions)} answer(s) from the person before the verdict");
            self.st.result = CaseReport(status="needs_input", questions=self.questions, steps=self.steps, facts=facts,
                agency=self.st.agency, register_status=self.register_status.name);
            if not self.quiet {
                report self.st.result;
            }
            disengage;
        }

        self.build_evidence_flags();
        findings = notes.summary + " " + " ".join(self.community);

        experts = notes.specialists or [Specialist.FEES];
        self.log("Supervisor", "route", "calling " + ", ".join([e.name.title() + " expert" for e in experts]));
        soft: list[RedFlag] = [];
        reviews: list[list[SoftFlag]] = [];
        with ThreadPoolExecutor(max_workers=3) as pool {
            futs = [pool.submit(specialist_review, _now()[:10], e, self.text, facts, findings) for e in experts];
            for (i, fut) in enumerate(futs) {
                try {
                    reviews.append(fut.result());
                } except Exception as e {
                    self.log("Supervisor", "agent_failed", f"{experts[i].name.title()} expert unavailable ({type(e).__name__}); continuing without it");
                    reviews.append([]);
                }
            }
        }
        for (i, e) in enumerate(experts) {
            res = reviews[i];
            name = e.name.title() + " expert";
            self.log(name, "review", f"{len(res)} warning sign(s)" + (": " + "; ".join([s.title for s in res]) if res else ""));
            soft.extend([soft_to_red(s, name) for s in res]);
        }

        hard = self.register_flags + self.community_flags + self.repost_flags + rule_flags(facts) + salary_flag(facts.salary_amount, facts.salary_currency, facts.job_title, self.text);
        candidates = dedupe(hard + soft);
        (kept, removed) = critic(candidates, self.text + "\n" + "\n".join(self.answers));
        for r in removed {
            self.log("Critic", "removed", r);
        }

        lines = _flag_lines(kept);
        prosecution: str = "";
        defence: str = "";
        with ThreadPoolExecutor(max_workers=2) as pool {
            pf = pool.submit(prosecute, self.text, findings, lines);
            df = pool.submit(defend, self.text, findings, lines);
            try {
                prosecution = pf.result();
            } except Exception as e {
                self.log("Supervisor", "agent_failed", f"Prosecutor unavailable ({type(e).__name__})");
                prosecution = "(Prosecutor unavailable) The case rests on the red flags listed.";
            }
            try {
                defence = df.result();
            } except Exception as e {
                self.log("Supervisor", "agent_failed", f"Defender unavailable ({type(e).__name__})");
                defence = "(Defender unavailable) No defence was heard, so no agent flag is dismissed.";
            }
        }
        self.log("Prosecutor", "argue", prosecution[:160]);
        self.log("Defender", "argue", defence[:160]);
        ruling = JudgeRuling(summary=f"Verdict from the transparent rules: {len(kept)} supported red flag(s).", dismissed=[]);
        try {
            ruling = judge_case(self.text, findings, lines, prosecution, defence);
        } except Exception as e {
            self.log("Supervisor", "agent_failed", f"Judge unavailable ({type(e).__name__}); keeping every supported flag");
        }
        final: list[RedFlag] = [];
        for (i, f) in enumerate(kept) {
            if (i + 1) in ruling.dismissed and f.source not in [SRC_REGISTER, SRC_COMMUNITY, SRC_GUIDANCE, SRC_SALARY] {
                self.log("Judge", "dismissed", f.title);
            } else {
                final.append(f);
            }
        }
        sc = score_flags(final);
        self.log("Judge", "verdict", f"{sc.band} ({sc.total}/100): {ruling.summary[:140]}");

        advice = Advice(
            questions_to_ask=["What is your SLBFE licence number?", "Can I get a written contract before paying anything?", "Will every payment have an official receipt from the agency's company account?"],
            next_steps=["Verify the agency on slbfe.lk or call the SLBFE 1989 hotline.", "Never hand over your passport or pay before verification.", "Travel only on an employment visa and register with the SLBFE before departure."],
            report_draft=""
        );
        try {
            advice = advise(self.text, sc.band, _flag_lines(final), findings);
        } except Exception as e {
            self.log("Supervisor", "agent_failed", f"Advisor unavailable ({type(e).__name__}); using standard SLBFE advice");
        }
        self.log("Advisor", "advise", f"{len(advice.questions_to_ask)} questions, {len(advice.next_steps)} next steps");

        (offer_id, alerts) = self.save_case(sc.band, sc.total, ruling.summary);

        sources = [Source(name=SRC_GUIDANCE, detail=GENERAL_GUIDANCE, url="https://www.slbfe.lk")];
        if self.register_status != RegisterStatus.NOT_CHECKED {
            reg_detail = f"status {self.register_status.name}, checked {self.register_checked_at}" if self.register_checked_at else "no agency name or licence number in the offer to look up";
            sources.insert(0, Source(name=SRC_REGISTER, detail=reg_detail, url="https://applications.slbfe.lk/feb/la/la_main.asp"));
        }
        if self.community {
            sources.append(Source(name=SRC_COMMUNITY, detail=" ".join(self.community)));
        }
        self.st.result = CaseReport(status="done", band=sc.band, score=sc.total, hard_points=sc.hard_points, soft_points=sc.soft_points,
            flags=final, removed=removed, prosecution=prosecution, defence=defence, judge=ruling.summary, advice=advice,
            agency=self.st.agency, register_status=self.register_status.name, community=self.community, alerts_sent=alerts,
            facts=facts, sources=sources, steps=self.steps, offer_id=offer_id,
            confidence=_confidence(facts, self.register_status != RegisterStatus.UNREACHABLE and self.register_status != RegisterStatus.NOT_CHECKED and "cached" not in self.register_checked_at, len([x for x in self.steps if x.action == "agent_failed"])));
        if not self.quiet {
            report self.st.result;
        }
    }
}

sem Investigate.investigate = "You are the Lead Investigator protecting a Sri Lankan job seeker. Decide your own investigation: use the tools to verify the agency on the live SLBFE register (by licence number if printed, else by name), check whether the offer's contacts belong to that agency, check community reports for each phone number, and read the destination country's guidance. Asking the person: if the visa type is NOT stated in the offer, you MUST call ask_user (e.g. 'What visa did they say you will travel on?'). If money is requested but it is unclear whether a written contract comes first, you MUST call ask_user about that too. Never ask about facts already in the offer or in the answers. Max 2 questions. Then summarise findings and pick the specialist reviewers.";
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
sem Investigate.salary_in_lkr = "Convert the offered monthly salary to Sri Lankan rupees to judge whether it is realistic for the job.";
sem Investigate.salary_in_lkr.amount = "Salary amount per month.";
sem Investigate.salary_in_lkr.currency = "Currency code, e.g. USD, QAR, AED.";
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

def ensure_sample_offers(r: Root) {
    if len([r -->[?:Offer]]) > 0 {
        return;
    }
    off1 = Offer(
        text="URGENT HIRING!!! IT / Data Entry jobs in THAILAND. Salary USD 1500 per month. Travel on tourist visa, pay Rs. 150,000 processing fee to confirm seat. Deposit to Commercial Bank account. WhatsApp +94 76 555 1234",
        job="IT / Data Entry", country="Thailand", agency_name="Unregistered Online Recruiter", verdict="DANGER", score=85,
        summary="Tourist visa scam for cyber scam compound / trafficking risk. Advance fee demanded.", created_at="2026-10-17 11:00");
    r ++> off1;
    ct1 = Contact(value="0765551234", kind="phone");
    r ++> ct1;
    off1 ++> ct1;

    off2 = Offer(
        text="Housemaid job in Dubai, salary AED 1500. Go on 3-month visit visa first. Sponsor will keep passport for safety. Contact Mrs. Silva 0712223344, pay Rs. 60,000 for ticket.",
        job="Housemaid", country="UAE", agency_name="Individual Broker (Mrs. Silva)", verdict="DANGER", score=90,
        summary="Visit visa employment trap and illegal withholding of passport. High risk of exploitation.", created_at="2026-10-17 11:30");
    r ++> off2;
    ct2 = Contact(value="0712223344", kind="phone");
    r ++> ct2;
    off2 ++> ct2;

    off3 = Offer(
        text="Security guard / helper jobs in RUSSIA. Salary USD 2500. Tourist visa provided. Leave within 1 week. Contact WhatsApp +7 925 000 1122",
        job="Security Guard", country="Russia", agency_name="Unknown Telegram Channel", verdict="DANGER", score=80,
        summary="High-risk recruitment to conflict zone on tourist visa without SLBFE clearance.", created_at="2026-10-17 12:00");
    r ++> off3;
    ct3 = Contact(value="79250001122", kind="phone");
    r ++> ct3;
    off3 ++> ct3;

    off4 = Offer(
        text="A T C GLOBAL HOLDINGS (PVT) LTD - Licence No 3500. Qatar House Driver. Registration fee Rs. 75,000 must be paid before interview. WhatsApp 0789 123 456",
        job="House Driver", country="Qatar", agency_name="A T C GLOBAL HOLDINGS (PVT) LTD", verdict="DANGER", score=75,
        summary="Impersonation scam using legitimate agency licence 3500 to extort upfront registration fee.", created_at="2026-10-17 12:30");
    r ++> off4;
    ct4 = Contact(value="0789123456", kind="phone");
    r ++> ct4;
    off4 ++> ct4;
}

walker:pub RecentChecks {
    has limit: int = 10;

    can list with Root entry {
        ensure_sample_offers(root);
        offers = [root -->[?:Offer]];
        offers = offers[-self.limit:];
        offers.reverse();
        for o in offers {
            report CheckView(id=jid(o), job=o.job, country=o.country, agency=o.agency_name, verdict=o.verdict,
                score=o.score, created_at=o.created_at, alerts=[a.message for a in [o -->[?:Alert]]]);
        }
    }
}

test "agency names match across spacing and suffixes" {
    assert _names_match("ATC Global Holdings", "A T C GLOBAL HOLDINGS (PVT) LTD");
    assert _names_match("A T C GLOBAL HOLDINGS (PVT) LTD", "A T C GLOBAL HOLDINGS (PVT) LTD");
    assert not _names_match("Lanka Gulf Dream Recruiters", "A T C GLOBAL HOLDINGS (PVT) LTD");
    assert not _names_match("Global Pvt Ltd", "ACTIVE GLOBAL SPECIALISED CAREGIVERS LANKA (PVT) LTD");
    assert _search_word("A T C GLOBAL HOLDINGS (PVT) LTD") == "holdings";
}
