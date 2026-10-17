"""Deterministic layer: official-rule flags, the evidence critic and the scorer.

The LLM never decides licence status or points. Code does.
"""
import re;
import from datetime { datetime }

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
glob SRC_SALARY = "Salary check (approximate fixed exchange rates)";

"""Approximate LKR per unit, fixed for the demo (Oct 2026). Used only for a sanity band, never to quote money."""
glob LKR_RATES: dict[str, float] = {
    "LKR": 1.0, "RS": 1.0, "USD": 300.0, "EUR": 330.0, "GBP": 390.0, "QAR": 82.0, "AED": 82.0, "SAR": 80.0,
    "KWD": 975.0, "OMR": 780.0, "BHD": 795.0, "MYR": 70.0, "SGD": 230.0, "JPY": 2.0, "KRW": 0.22,
    "ILS": 80.0, "RUB": 3.5, "THB": 9.0, "MVR": 19.5, "AUD": 195.0, "CAD": 215.0
};

glob UNSKILLED_WORDS: list[str] = ["driver", "housemaid", "maid", "domestic", "cleaner", "cleaning", "helper", "labour", "labor", "factory", "data entry", "typing", "packing", "security", "guard", "caregiver", "waiter", "kitchen", "farm", "construction", "general worker"];

"""Unskilled-job ceiling: a monthly salary above this for a no-experience job is a classic bait (about USD 1,500)."""
glob UNSKILLED_CEILING_LKR: float = 450000.0;

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

"""Pattern-based extraction used by the Supervisor to double-check the Extractor agent."""
def find_phones(text: str) -> list[str] {
    out: list[str] = [];
    for m in re.findall(r"\+?\d[\d\s\-]{7,16}\d", text) {
        raw: str = m;
        digits = re.sub(r"\D", "", raw);
        local = "";
        if raw.strip().startswith("+94") and len(digits) == 11 {
            local = "0" + digits[2:];
        } elif digits.startswith("0") and len(digits) == 10 {
            local = digits;
        } elif raw.strip().startswith("+") and 9 <= len(digits) <= 13 {
            local = "+" + digits;
        }
        if local and local not in out {
            out.append(local);
        }
    }
    return out;
}

def find_emails(text: str) -> list[str] {
    found: list[str] = re.findall(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}", text);
    return [e.lower() for e in found];
}

def find_licence(text: str) -> str {
    hits: list[str] = re.findall(r"(?i)licen[cs]e\s*(?:no\.?|number|#)?\s*[:\-]?\s*(\d{3,5})", text);
    return hits[0] if hits else "";
}

def find_visa_word(text: str) -> str {
    low = text.lower();
    for w in ["tourist visa", "visit visa", "employment visa", "work visa", "student visa"] {
        if w in low {
            return w;
        }
    }
    return "";
}

"""Monthly salary in LKR using fixed approximate rates; -1 if the currency is unknown."""
def to_lkr(amount: float, currency: str) -> float {
    code = re.sub(r"[^A-Z]", "", currency.upper());
    if code in LKR_RATES {
        return amount * LKR_RATES[code];
    }
    return -1.0;
}

def is_unskilled(job_title: str, text: str) -> bool {
    low = (job_title + " " + text).lower();
    return "no experience" in low or any([w in low for w in UNSKILLED_WORDS]);
}

"""Flag pay that is too good to be true for an unskilled job (deterministic, no LLM)."""
def salary_flag(amount: float, currency: str, job_title: str, text: str) -> list[RedFlag] {
    lkr = to_lkr(amount, currency);
    if amount <= 0 or lkr < 0 or not is_unskilled(job_title, text) or lkr <= UNSKILLED_CEILING_LKR {
        return [];
    }
    return [RedFlag(code="SALARY_BAIT", title="Salary too good to be true for this job", points=15,
        evidence=f"{amount:,.0f} {currency} per month is about Rs. {lkr:,.0f}",
        explanation=f"Unskilled or no-experience jobs abroad rarely pay more than about Rs. {UNSKILLED_CEILING_LKR:,.0f} a month. Very high pay is a common way to lure people into scams or trafficking.",
        source=SRC_SALARY, agent="Rules engine")];
}

"""Licence-expiry check from the register's 'Valid upto' date (e.g. 14-May-2027). today = YYYY-MM-DD."""
def licence_expiry_flag(valid_upto: str, agency_name: str, today: str) -> list[RedFlag] {
    try {
        end = datetime.strptime(valid_upto.strip(), "%d-%b-%Y");
        now = datetime.strptime(today, "%Y-%m-%d");
    } except Exception {
        return [];
    }
    days = (end - now).days;
    if days < 0 {
        return [RedFlag(code="LICENCE_EXPIRED", title="Agency licence has expired", points=35,
            evidence=f"{agency_name}: licence valid until {valid_upto}",
            explanation="The SLBFE register shows this agency's licence end date has passed. An agency may not recruit without a valid licence; ask SLBFE (1989) whether a renewal is pending before paying.",
            source=SRC_REGISTER, agent="Supervisor")];
    }
    if days <= 30 {
        return [RedFlag(code="LICENCE_EXPIRING", title="Agency licence expires within 30 days", points=10,
            evidence=f"{agency_name}: licence valid until {valid_upto} ({days} days left)",
            explanation="Recruitment takes weeks. If the licence lapses before you travel you may lose SLBFE protection. Ask whether the renewal has been filed.",
            source=SRC_REGISTER, agent="Supervisor")];
    }
    return [];
}

"""Word 3-gram Jaccard similarity (0..1) between two offer texts; digits are ignored so the same ad with new numbers still matches."""
def text_similarity(a: str, b: str) -> float {
    def grams(t: str) -> set[str] {
        words = re.sub(r"[^a-z ]+", " ", t.lower()).split();
        return set([" ".join(words[i:i + 3]) for i in range(max(len(words) - 2, 0))]);
    }
    ga = grams(a);
    gb = grams(b);
    if not ga or not gb {
        return 0.0;
    }
    return len(ga & gb) / len(ga | gb);
}

"""Critic: keep a flag only if its evidence is literally in the offer (register/community flags are exempt)."""
def critic(flags: list[RedFlag], text: str) -> tuple[list[RedFlag], list[str]] {
    kept: list[RedFlag] = [];
    removed: list[str] = [];
    for f in flags {
        exempt = f.source == SRC_REGISTER or f.source == SRC_COMMUNITY or f.source == SRC_SALARY;
        if exempt or evidence_in_text(f.evidence, text) {
            kept.append(f);
        } else {
            removed.append(f"{f.title} (quoted words not found in the offer)");
        }
    }
    return (kept, removed);
}

"""Drop repeats: same title, or an agent flag quoting evidence another flag already covers."""
def dedupe(flags: list[RedFlag]) -> list[RedFlag] {
    seen_titles: set[str] = set();
    seen_evidence: set[str] = set();
    out: list[RedFlag] = [];
    for f in flags {
        key = _norm(f.title)[:40];
        ev = _norm(f.evidence);
        if key in seen_titles {
            continue;
        }
        if f.source == SRC_AGENT and ev and ev in seen_evidence {
            continue;
        }
        seen_titles.add(key);
        if ev {
            seen_evidence.add(ev);
        }
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

test "dedupe drops agent flags repeating covered evidence" {
    hard = RedFlag(code="PASSPORT", title="Employer keeps your passport", points=25, evidence="Sponsor will keep passport", explanation="", source=SRC_GUIDANCE, agent="");
    soft = RedFlag(code="AGENT", title="Passport Confiscation", points=10, evidence="Sponsor will keep passport", explanation="", source=SRC_AGENT, agent="");
    other = RedFlag(code="AGENT", title="Pressure to pay", points=5, evidence="Only 5 seats left", explanation="", source=SRC_AGENT, agent="");
    assert len(dedupe([hard, soft, other])) == 2;
}

test "pattern extraction finds phones, licence and visa but not bank accounts" {
    t = "Licence No 3500. Pay to account 8012345678. WhatsApp +94 76 555 1234 or 0112818268. Mail info@atcs.lk. Travel on tourist visa.";
    assert find_phones(t) == ["0765551234", "0112818268"];
    assert find_licence(t) == "3500";
    assert find_emails(t) == ["info@atcs.lk"];
    assert find_visa_word(t) == "tourist visa";
    assert find_phones("Call +7 925 000 1122 now") == ["+79250001122"];
    assert find_licence("no licence printed") == "";
}

test "salary bait rule" {
    assert to_lkr(1500.0, "USD") == 450000.0;
    assert to_lkr(10.0, "XYZ") == -1.0;
    assert len(salary_flag(2500.0, "USD", "Security guard", "no experience")) == 1;
    assert len(salary_flag(2000.0, "QAR", "Light vehicle driver", "")) == 0;
    assert len(salary_flag(3000.0, "USD", "Software engineer", "5 years experience")) == 0;
}

test "licence expiry rule" {
    assert licence_expiry_flag("14-May-2027", "ATC", "2026-10-17") == [];
    assert licence_expiry_flag("01-Nov-2026", "ATC", "2026-10-17")[0].code == "LICENCE_EXPIRING";
    assert licence_expiry_flag("01-Oct-2026", "ATC", "2026-10-17")[0].code == "LICENCE_EXPIRED";
    assert licence_expiry_flag("not a date", "ATC", "2026-10-17") == [];
}

test "duplicate detector similarity ignores changed numbers" {
    a = "URGENT HIRING IT data entry jobs in Thailand salary USD 1500 free accommodation pay processing fee WhatsApp 0765551234";
    b = "URGENT HIRING IT data entry jobs in Thailand salary USD 1800 free accommodation pay processing fee WhatsApp 0771112222";
    assert text_similarity(a, b) > 0.8;
    assert text_similarity(a, "Qatar light vehicle driver employment visa contract before departure") < 0.1;
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
