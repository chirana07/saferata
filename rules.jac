"""Deterministic layer: official-rule flags, the evidence critic and the scorer.

The LLM never decides licence status or points. Code does.
"""
import re;
import from graph { OfferFacts, SoftFlag, Severity }

obj RedFlag {
    has code: str,
        title: str,
        points: int,
        evidence: str,
        explanation: str,
        source: str,
        agent: str;
}

obj Score {
    has total: int,
        band: str,
        hard_points: int,
        soft_points: int;
}

enum RegisterStatus { VERIFIED, NOT_FOUND, NAME_MISMATCH, UNREACHABLE, NOT_CHECKED }

glob SRC_REGISTER = "SLBFE licensed-agency register (live)";
glob SRC_GUIDANCE = "SLBFE public guidance";
glob SRC_COMMUNITY = "SafeRata community reports";
glob SRC_AGENT = "Agent judgement (evidence quoted)";

"""Country notes the investigator can consult. Summarised from SLBFE / government public warnings."""
glob COUNTRY_GUIDANCE: dict[str, str] = {
    "south korea": "Jobs in South Korea (EPS scheme) are recruited government-to-government through the SLBFE after the EPS-TOPIK exam. A private agent selling Korean factory jobs for a fee is a red flag.",
    "korea": "Jobs in South Korea (EPS scheme) are recruited government-to-government through the SLBFE after the EPS-TOPIK exam. A private agent selling Korean factory jobs for a fee is a red flag.",
    "israel": "Caregiver and agriculture jobs in Israel are recruited through the SLBFE government programme. Be wary of private agents demanding large fees for Israel jobs.",
    "thailand": "Sri Lankan authorities have warned that 'IT', 'data entry' or 'customer service' jobs in Thailand have been used to traffic people into cyber-scam compounds in Myanmar. Tourist-visa travel with paid flights is a classic pattern.",
    "myanmar": "Myanmar border areas host cyber-scam compounds where trafficked foreigners, including Sri Lankans, have been held. Treat any job offer there as high risk.",
    "cambodia": "Scam compounds in Cambodia have trafficked foreign workers through fake online jobs. Treat 'online marketing / IT' offers as high risk.",
    "laos": "Scam compounds in Laos (Golden Triangle) have trafficked foreign workers through fake online jobs.",
    "russia": "The Sri Lankan government has warned that Sri Lankans were recruited with job promises and ended up in the Russian military. Treat 'security' or 'helper' jobs in Russia offered by unofficial agents as very high risk.",
    "qatar": "Work in Qatar requires an employment visa sponsored by the employer and SLBFE registration before departure.",
    "uae": "Work in the UAE requires an employment visa / work permit. Travelling on a visit visa to look for work is risky and not protected by SLBFE insurance.",
    "dubai": "Work in the UAE requires an employment visa / work permit. Travelling on a visit visa to look for work is risky and not protected by SLBFE insurance.",
    "saudi arabia": "Work in Saudi Arabia requires an employment visa from the employer. Workers must register with the SLBFE before departure.",
    "kuwait": "Work in Kuwait requires an employment visa from the employer. Workers must register with the SLBFE before departure.",
    "japan": "Japan jobs (Specified Skilled Worker / technical intern) go through SLBFE-approved agencies, which may only charge up to the SLBFE-listed maximum fee. Ask for the official fee and a receipt."
};

glob GENERAL_GUIDANCE = "SLBFE guidance: verify the agency licence on slbfe.lk or the 1989 hotline before paying; never hand over your passport or money before verification; travel only on an employment visa; register with the SLBFE before departure; insist on receipts for every payment.";

def country_note(country: str) -> str {
    key = country.strip().lower();
    if key in COUNTRY_GUIDANCE {
        return COUNTRY_GUIDANCE[key];
    }
    return "No country-specific note. " + GENERAL_GUIDANCE;
}

def _norm(s: str) -> str {
    return re.sub(r"[^a-z0-9]+", " ", s.lower()).strip();
}

"""Does the quoted evidence really appear in the offer text?"""
def evidence_in_text(evidence: str, text: str) -> bool {
    ev = _norm(evidence);
    if len(ev) < 3 {
        return False;
    }
    return ev in _norm(text);
}

"""Hard flags that come from official rules applied to the extracted facts."""
def rule_flags(facts: OfferFacts) -> list[RedFlag] {
    flags: list[RedFlag] = [];
    visa = facts.visa_type.lower();
    if "visit" in visa or "tourist" in visa {
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

"""Critic: keep a flag only if its evidence is literally in the offer (register/community flags are exempt)."""
def critic(flags: list[RedFlag], text: str) -> tuple[list[RedFlag], list[str]] {
    kept: list[RedFlag] = [];
    removed: list[str] = [];
    for f in flags {
        exempt = f.source == SRC_REGISTER or f.source == SRC_COMMUNITY;
        if exempt or evidence_in_text(f.evidence, text) {
            kept.append(f);
        } else {
            removed.append(f"{f.title} (quoted words not found in the offer)");
        }
    }
    return (kept, removed);
}

def dedupe(flags: list[RedFlag]) -> list[RedFlag] {
    seen: set[str] = set();
    out: list[RedFlag] = [];
    for f in flags {
        key = _norm(f.title)[:40];
        if key in seen {
            continue;
        }
        seen.add(key);
        out.append(f);
    }
    return out;
}

"""Transparent points: hard flags count in full, agent judgement capped at 20."""
def score_flags(flags: list[RedFlag]) -> Score {
    hard = 0;
    soft = 0;
    critical = False;
    for f in flags {
        if f.source == SRC_AGENT {
            soft += f.points;
        } else {
            hard += f.points;
            if f.points >= 25 {
                critical = True;
            }
        }
    }
    soft = min(soft, 20);
    total = min(hard + soft, 100);
    band = "LOOKS SAFE";
    if total >= 60 {
        band = "DANGER";
    } elif total >= 25 or critical {
        band = "BE CAREFUL";
    }
    return Score(total=total, band=band, hard_points=hard, soft_points=soft);
}

test "evidence critic matches verbatim quotes loosely" {
    text = "Pay Rs. 350,000 to my account 1234 before Friday!";
    assert evidence_in_text("pay rs 350,000 to my account", text);
    assert not evidence_in_text("passport will be kept", text);
}

test "scoring bands" {
    f1 = RedFlag(code="X", title="a", points=40, evidence="", explanation="", source=SRC_REGISTER, agent="");
    f2 = RedFlag(code="Y", title="b", points=30, evidence="", explanation="", source=SRC_GUIDANCE, agent="");
    assert score_flags([f1, f2]).band == "DANGER";
    s = RedFlag(code="AGENT", title="c", points=10, evidence="", explanation="", source=SRC_AGENT, agent="");
    assert score_flags([s, s, s]).soft_points == 20;
    assert score_flags([]).band == "LOOKS SAFE";
    assert score_flags([f2]).band == "BE CAREFUL";
}
