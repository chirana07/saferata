"""Deterministic layer: official-rule flags, the evidence critic and the scorer.

The LLM never decides licence status or points. Code does.
"""
import re;

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

test "scoring bands" {
    f1 = RedFlag(code="X", title="a", points=40, evidence="", explanation="", source=SRC_REGISTER, agent="");
    f2 = RedFlag(code="Y", title="b", points=30, evidence="", explanation="", source=SRC_GUIDANCE, agent="");
    assert score_flags([f1, f2]).band == "DANGER";
    s = RedFlag(code="AGENT", title="c", points=10, evidence="", explanation="", source=SRC_AGENT, agent="");
    assert score_flags([s, s, s]).soft_points == 20;
    assert score_flags([]).band == "LOOKS SAFE";
    assert score_flags([f2]).band == "BE CAREFUL";
}
