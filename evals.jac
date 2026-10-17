"""Evaluation set: run labelled sample offers through the full agent team and score the verdicts.

Run: jac run --no-takeover evals.jac   (needs model keys; takes a few minutes)
"""
import from agents { Investigate, CaseReport }

obj EvalCase {
    has name: str,
        text: str,
        expected: list[str];
}

glob CASES: list[EvalCase] = [
    EvalCase(name="Thailand IT job (trafficking)", expected=["DANGER"],
        text="URGENT HIRING!!! IT / Data Entry jobs in THAILAND. Salary USD 1500 per month + free accommodation. No experience needed. Air ticket FREE. Travel on tourist visa, company will change to work visa after arrival. Only 5 seats left - pay Rs. 150,000 processing fee. Deposit to Commercial Bank account 8012345678 (K. Perera). WhatsApp +94 76 555 1234"),
    EvalCase(name="Licensed agency impersonated", expected=["DANGER", "BE CAREFUL"],
        text="A T C GLOBAL HOLDINGS (PVT) LTD - Licence No 3500. Qatar - House Driver vacancies. Salary QAR 1800. Employment visa. Registration fee Rs. 75,000 must be paid before interview to reserve your place. Contact our recruitment officer on WhatsApp 0789 123 456"),
    EvalCase(name="Genuine licensed offer", expected=["LOOKS SAFE"],
        text="A T C GLOBAL HOLDINGS (PVT) LTD (SLBFE Licence No 3500). Vacancy: Light vehicle driver - Qatar. Employment visa sponsored by employer. Salary QAR 2000 + accommodation. 2-year contract provided before departure. All payments only at our Nugegoda office with official receipt, after you sign the contract. Call 0112818268 or email info@atcs.lk"),
    EvalCase(name="Fake licence number", expected=["DANGER"],
        text="LANKA GULF DREAM RECRUITERS - SLBFE Licence 9998. Kuwait cleaning jobs, salary KWD 120. Pay Rs. 90,000 now to block your seat, balance after visa. Call 0771234567"),
    EvalCase(name="Dubai housemaid on visit visa", expected=["DANGER", "BE CAREFUL"],
        text="Housemaid job in Dubai, salary AED 1500. Go on 3-month visit visa first, madam will arrange work visa later. Sponsor will keep passport for safety. Contact Mrs. Silva 0712223344, pay Rs. 60,000 for ticket to her account."),
    EvalCase(name="Russia security job", expected=["DANGER", "BE CAREFUL"],
        text="Security guard / helper jobs in RUSSIA. Salary USD 2500 + bonus. Free flight, free food. No experience, age 20-45 men only. Contact on WhatsApp +7 925 000 1122. Tourist visa provided. Leave within 1 week.")
];

with entry:__main__ {
    passed = 0;
    for c in CASES {
        inv = Investigate(text=c.text, answers=["No further information available."]);
        root spawn inv;
        r = inv.result;
        band = r.band if r is not None else "ERROR";
        score = r.score if r is not None else -1;
        ok = band in c.expected;
        if ok {
            passed += 1;
        }
        print(f"{'PASS' if ok else 'FAIL'} | {c.name:<32} | got {band:<10} {score:>3}/100 | expected {' or '.join(c.expected)}");
    }
    print(f"\n{passed}/{len(CASES)} verdicts correct");
}
