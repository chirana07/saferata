"""Persistent community graph and the typed objects the agents exchange.

Root ─▶ Offer ─▶ Agency          (agency named in the offer, as found on the SLBFE register)
Root ─▶ Contact ◀─ Offer          (normalised phone / email shared by many offers)
Offer ─▶ Alert                    (raised when a linked offer is later judged Danger)
"""

node Agency {
    has licence_no: str,
        name: str,
        phones: list[str] = [],
        email: str = "",
        valid_upto: str = "",
        checked_at: str = "";
}

node Contact {
    has value: str,
        kind: str;
}

node Offer {
    has text: str,
        job: str = "",
        country: str = "",
        agency_name: str = "",
        verdict: str = "",
        score: int = 0,
        summary: str = "",
        created_at: str = "";
}

node Alert {
    has message: str,
        created_at: str;
}

# ---------- objects the agents fill in (LLM schemas) ----------

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

sem OfferFacts = "Facts extracted from a foreign job offer. Copy evidence strings VERBATIM from the offer text (a short exact quote), or leave them empty.";
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

sem SoftFlag = "A warning sign an expert spotted in the offer.";
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
