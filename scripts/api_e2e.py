"""End-to-end backend checks against a running SafeRata server (any jac version)."""
import json, sys, time, urllib.request
BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000"
def call(w, body):
    req = urllib.request.Request(f"{BASE}/walker/{w}", data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    try:
        d = json.load(urllib.request.urlopen(req, timeout=300))
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{w} HTTP {e.code}: {e.read()[:400]}")
    reps = d.get("data", {}).get("reports") if isinstance(d.get("data"), dict) else d.get("reports")
    if reps is None: raise SystemExit(f"{w}: unexpected envelope keys {list(d)}")
    return reps
results = []
def check(name, cond, info=""):
    results.append((name, cond)); print(("PASS " if cond else "FAIL ") + name + ("  | " + info if info else ""))

t = time.time()
r = call("Investigate", {"text": "URGENT HIRING!!! IT / Data Entry jobs in THAILAND. Salary USD 1500. Travel on tourist visa, company will change to work visa after arrival. Pay Rs. 150,000 processing fee. Deposit to Commercial Bank account 8012345678 (K. Perera). WhatsApp +94 76 555 1234"})
c = r[-1]; check("Thailand offer -> DANGER", c["band"] == "DANGER", f'{c["band"]} {c["score"]} in {time.time()-t:.0f}s, {len(c["steps"])} steps')
check("one report per Investigate call", len(r) == 1, str(len(r)))

vague = "Hi brother, good job in Saudi Arabia, driver, salary SAR 2000. Our sir can arrange everything quickly. Send your passport copy and Rs. 50,000 to start the process. Call Kamal 0751112233"
r = call("Investigate", {"text": vague}); c = r[-1]
check("vague offer -> asks the person", c["status"] == "needs_input" and len(c["questions"]) > 0, str(c["questions"]))
r = call("Investigate", {"text": vague, "answers": [f"Q: {q} A: visit visa first, they said work visa later" for q in c["questions"]]}); c = r[-1]
check("after answers -> verdict", c["status"] == "done" and c["band"] in ("DANGER", "BE CAREFUL"), f'{c["band"]} {c["score"]}')

r = call("PostJob", {"title": "Welder", "country": "Qatar", "salary": "QAR 2200", "description": "Employment visa sponsored by employer. Contract signed before departure. Payments only at our Nugegoda office with official receipt.", "licence_no": "3500", "contact_phone": "0112818268"})
check("PostJob returns one report", len(r) == 1, str(len(r)))
j = r[0]["job"]; check("genuine job -> LOOKS SAFE", j["band"] == "LOOKS SAFE", f'{j["band"]} {j["score"]}')
r = call("PostJob", {"title": "X", "country": "Qatar", "salary": "1", "description": "x", "licence_no": "9998", "contact_phone": "0771234567"})
check("unlicensed agency cannot post", r[0]["ok"] is False, r[0]["message"][:80])

r = call("AddReview", {"job_id": j["id"], "author": "Kasun", "kind": "fraud", "text": "On 8 Oct 2026 a man called from 0769998877 saying he is from this agency's Qatar welder recruitment, took Rs. 80,000 by personal transfer and disappeared. The office later said he is not their staff.", "evidence": "Bank transfer 08-10-2026 Rs 80,000 to M. Perera; caller number 0769998877"})
x = r[0]["job"]
check("impersonation review -> agency score unchanged", x["score"] == j["score"], f'{x["band"]} {x["score"]}')
check("impersonation review -> warning names scam number", any("0769998877" in w for w in x["warnings"]), str(x["warnings"])[:120])

r = call("AddReview", {"job_id": j["id"], "author": "Saman", "kind": "fraud", "text": "I paid Rs. 150,000 at the agency's Nugegoda office on 1 Sep 2026 for this welder job. They gave a receipt but after 6 weeks no visa, no refund, and the office staff now refuse to meet me.", "evidence": "Official receipt no. 4471 from A T C Global Holdings dated 01-09-2026 for Rs 150,000"})
x = r[0]["job"]; check("direct agency-fraud review -> re-scored up", x["score"] > j["score"], f'{x["band"]} {x["score"]}')

r = call("RecentChecks", {}); check("community feed lists checks", len(r) >= 3, f"{len(r)} checks")
print(f"\n{sum(1 for _, ok in results if ok)}/{len(results)} backend checks passed")
