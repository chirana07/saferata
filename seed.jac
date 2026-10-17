"""Demo seed: loads a clean, realistic history through the running server's API.

Usage (server must be running):  jac run seed.jac            (default http://localhost:8000)
Reset first with:                jac clean --data --force   (then restart `jac start`)

Ethics note: job-board listings must use a real SLBFE licence (the live gate rejects anything else), so the
board listings below are ordinary, genuine-looking jobs. The only negative report against them is an
IMPERSONATION report, which by design does not lower the agency's own score. All scam examples are pasted
offers with fictional recruiter names, checked through "Check an offer".
"""
import json;
import os;
import urllib.request;

glob BASE = os.getenv("SAFERATA_URL", "http://localhost:8000");

def call(name: str, body: dict) -> list {
    req = urllib.request.Request(BASE + "/walker/" + name, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"});
    resp = urllib.request.urlopen(req, timeout=300);
    d = json.loads(resp.read().decode());
    resp.close();
    data = d.get("data", {});
    return data.get("reports", []) if isinstance(data, dict) else [];
}

glob LISTINGS: list[dict] = [
    {"title": "Light vehicle driver", "country": "Qatar", "salary": "QAR 2,000 + accommodation", "licence_no": "3500", "contact_phone": "0112818268",
     "description": "Employment visa sponsored by the employer. 2-year contract signed in Colombo before departure. Accommodation and transport provided. Any agency charges are paid only at our Nugegoda office against an official receipt, after you sign the contract."},
    {"title": "Hotel housekeeping attendant", "country": "United Arab Emirates", "salary": "AED 1,600", "licence_no": "3500", "contact_phone": "0715217978",
     "description": "Employment visa (work permit) issued by the hotel. 2-year renewable contract. Shared staff accommodation and meals. SLBFE registration done before departure; no fee is collected before the contract is signed."},
    {"title": "Commis chef", "country": "Saudi Arabia", "salary": "SAR 2,400", "licence_no": "3500", "contact_phone": "0771605640",
     "description": "Employment visa sponsored by the employer. NVQ Level 3 cookery preferred. 2-year contract, accommodation provided, 30 days annual leave. Contract and fees explained at our office with an official receipt for every payment."}
];

glob CHECKS: list[str] = [
    "URGENT HIRING!!! IT / Data Entry jobs in THAILAND\nSalary USD 1500 per month + free accommodation + food\nNo experience needed, basic English and typing only.\nAir ticket FREE. Travel on tourist visa, company will change to work visa after arrival.\nOnly 5 seats left - pay Rs. 150,000 processing fee to confirm your seat.\nDeposit to Commercial Bank account 8012345678 (K. Perera). Send slip on WhatsApp +94 76 555 1234",
    "Housemaid job in Dubai, salary AED 1500. Go on 3-month visit visa first, madam will arrange work visa later. Sponsor will keep passport for safety. Contact Mrs. Silva 0712223344, pay Rs. 60,000 for ticket to her account.",
    "LANKA GULF DREAM RECRUITERS - SLBFE Licence 9998. Kuwait cleaning jobs, salary KWD 120. Pay Rs. 90,000 now to block your seat, balance after visa. Call 0771234567",
    "Security guard / helper jobs in RUSSIA. Salary USD 2500 + bonus. Free flight, free food. No experience, age 20-45 men only. Contact on WhatsApp +7 925 000 1122. Tourist visa provided. Leave within 1 week.",
    "A T C GLOBAL HOLDINGS (PVT) LTD - Licence No 3500\nQatar - House Driver vacancies. Salary QAR 1800. Employment visa.\nRegistration fee Rs. 75,000 must be paid before interview to reserve your place.\nContact our recruitment officer on WhatsApp 0789 123 456"
];

with entry:__main__ {
    print("Seeding", BASE);
    job_ids: list[str] = [];
    for l in LISTINGS {
        r = call("PostJob", l);
        if r and r[0].get("ok") {
            j = r[0]["job"];
            job_ids.append(str(j["id"]));
            print("  job:", j["title"], "->", j["band"], j["score"]);
        } else {
            print("  job FAILED:", l["title"], r[0].get("message") if r else "no report");
        }
    }
    for t in CHECKS {
        r = call("Investigate", {"text": t, "answers": ["No further information available."]});
        c = r[-1] if r else {};
        print("  check:", t[:50].replace("\n", " "), "->", c.get("band"), c.get("score"));
    }
    if job_ids {
        r = call("AddReview", {"job_id": job_ids[0], "author": "Kasun", "kind": "fraud",
            "text": "On 8 Oct 2026 a man called from 0789123456 saying he recruits Qatar drivers for this agency. He took Rs. 75,000 by bank transfer as a 'registration fee' and stopped answering. When I visited the Nugegoda office they said he is not their staff and they never charge before the contract.",
            "evidence": "Bank transfer 08-10-2026, Rs. 75,000 to an individual's account; WhatsApp from 0789123456: 'pay today to reserve your Qatar driver seat'"});
        if r {
            print("  impersonation report ->", r[0]["message"], r[0]["job"]["band"], r[0]["job"]["score"]);
        }
        r = call("AddReview", {"job_id": job_ids[1] if len(job_ids) > 1 else job_ids[0], "author": "Dilani", "kind": "positive",
            "text": "Placed as housekeeping attendant in Dubai in March 2026. The contract I received on arrival was identical to the one I signed in Colombo, and the only fee was paid at the office with a receipt.",
            "evidence": "Official receipt from the agency office; signed contract copy dated 02-03-2026"});
        if r {
            print("  positive review ->", r[0]["message"]);
        }
    }
    print("Done.");
}
