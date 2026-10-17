"""Verify Test 5 (Worker Profile & Skills Matching) and Test 6 (Agency Portal & Job Posting)."""

import json, sys, urllib.request

BASE = "http://localhost:8000"

def call(walker, body):
    req = urllib.request.Request(
        f"{BASE}/walker/{walker}",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"}
    )
    res = urllib.request.urlopen(req, timeout=60)
    data = json.load(res)
    return data.get("data", {}).get("reports", []) if isinstance(data.get("data"), dict) else data.get("reports", [])

print("=" * 65)
print("  SAFARATA VERIFICATION: TEST 5 (PROFILE) & TEST 6 (AGENCY PORTAL)")
print("=" * 65)

# -------------------------------------------------------------
# TEST 5: Worker Profile & AI Skills Matching
# -------------------------------------------------------------
print("\n[TEST 5] Submitting Worker Profile & Testing MatchJobs Walker...")
profile = {
    "occupation": "Driver",
    "skills": ["Heavy vehicle", "English", "GCC experience"],
    "destinations": ["Qatar", "Saudi Arabia"],
    "min_salary_lkr": 150000.0,
    "experience_years": 3,
    "needs_accommodation": True
}

matches = call("MatchJobs", profile)
print(f" -> Received {len(matches)} job matches from graph:")
for m in matches:
    print(f"    * Job ID: {m['job_id'][:8]} | Match Score: {m['match']}%")
    if m.get('reasons'):
        print(f"      Reasons : {m['reasons']}")
    if m.get('cautions'):
        print(f"      Cautions: {m['cautions']}")

assert len(matches) > 0, "Expected at least 1 job match for profile"
top_match = max(matches, key=lambda x: x['match'])
print(f"\n -> TEST 5 RESULT: SUCCESS! Top Match is {top_match['match']}% ({top_match['reasons']})")

# -------------------------------------------------------------
# TEST 6: Agency Portal - Negative (Unlicensed) & Positive (Licensed)
# -------------------------------------------------------------
print("\n[TEST 6A] Testing Negative Case: Fake SLBFE Licence 9998...")
fake_job = {
    "title": "Forklift Operator",
    "country": "Kuwait",
    "salary": "KWD 250",
    "description": "Forklift driving in warehouse. High pay.",
    "licence_no": "9998",
    "contact_phone": "0771234567"
}

fake_res = call("PostJob", fake_job)
print(f" -> Server Response: ok={fake_res[0].get('ok')}")
print(f"    Message: {fake_res[0].get('message')}")
assert fake_res[0].get('ok') is False, "Unlicensed agency job should be rejected"
print(" -> TEST 6A RESULT: SUCCESS! Unlicensed agency was strictly blocked.")

print("\n[TEST 6B] Testing Positive Case: Licensed Agency (ATC Global, Licence 3500)...")
valid_job = {
    "title": "Storekeeper",
    "country": "Qatar",
    "salary": "QAR 2500",
    "description": "Employment visa sponsored by company. Contract signed before departure in Colombo. Payments only at our Nugegoda office against official receipt.",
    "licence_no": "3500",
    "contact_phone": "0112818268"
}

valid_res = call("PostJob", valid_job)
print(f" -> Server Response: ok={valid_res[0].get('ok')}")
job_data = valid_res[0].get('job', {})
print(f"    Created Job ID: {job_data.get('id')[:8]}")
print(f"    Title         : {job_data.get('title')}")
print(f"    Agency        : {job_data.get('agency_name')}")
print(f"    Safety Verdict: {job_data.get('band')} (Score: {job_data.get('score')}/100)")
print(f"    Take-home LKR : Rs. {job_data.get('take_home_lkr'):,.0f} / mo")

assert valid_res[0].get('ok') is True, "Valid agency job should be accepted"
assert job_data.get('band') == "LOOKS SAFE", "Pre-screened valid job should be LOOKS SAFE"
print(" -> TEST 6B RESULT: SUCCESS! Legitimate job pre-screened and posted to public board.")

print("\n" + "=" * 65)
print("  ALL VERIFICATIONS FOR TEST 5 & TEST 6 PASSED (100%)")
print("=" * 65)
