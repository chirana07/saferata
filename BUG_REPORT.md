# SafeRata: Defect Register & Resolution Report

**Document Version:** 1.0.0  
**Date:** 2026-10-17  
**Total Defects Identified:** 2  
**Total Defects Resolved:** 2  
**Open Critical/High Defects:** 0

---

## Defect Summary Table

| Defect ID | Severity | Component | Summary | Status | Retest Result |
|---|---|---|---|---|---|
| **BUG-01** | **High** | `slbfe.jac` | Empty licence string acted as wildcard query on SLBFE government portal, returning first alphabetical agency record | **RESOLVED** | **PASS** |
| **BUG-02** | **Medium** | `jobboard.jac` | `PostJob` & `AddReview` lacked non-empty string validation, allowing blank jobs and empty reviews to proceed | **RESOLVED** | **PASS** |

---

## Granular Defect Details

### BUG-01: Empty Licence Number Wildcard Matching in SLBFE Scraper
- **Defect ID:** BUG-01
- **Severity:** High
- **Component:** `slbfe.jac` (`search_by_licence`, `search_by_name`)
- **Preconditions:** Server running; user submits empty or whitespace licence number to `search_by_licence("")`.
- **Reproduction Steps:**
  1. Send POST request to `/walker/PostJob` with `{"licence_no": ""}`.
  2. `search_by_licence` stripped non-digits and posted `{"an": ""}` to `applications.slbfe.lk`.
- **Expected Behavior:** An empty or non-numeric query should return 0 records immediately (`records: []`) without querying the external portal.
- **Actual Behavior:** The SLBFE portal interpreted `an=""` as a wildcard search and returned the entire register, starting with the very first alphabetical agency (`"A & B TRAVELS", Licence 1712`). `PostJob` erroneously considered the blank licence verified.
- **Root Cause:** Missing non-empty guard before sending HTTP POST payload in `slbfe.jac`.
- **Fix Applied:** Added guard in `slbfe.jac`:
  ```jac
  def search_by_licence(licence_no: str) -> RegisterResult {
      digits = re.sub(r"\D", "", licence_no);
      if not digits {
          return RegisterResult(ok=True, records=[], checked_at=datetime.now().strftime("%Y-%m-%d %H:%M"));
      }
      return _post({"an": digits, "agency": "", "address": "", "District": "", "country": "", "Search": "Search"});
  }
  ```
- **Regression Test:** `TC-15` & `TC-31` in `scripts/comprehensive_test_suite.py`.
- **Retest Result:** **PASS** (Zero records returned on blank search; invalid licence rejected immediately).

---

### BUG-02: Missing Input Validation on `PostJob` and `AddReview` Walkers
- **Defect ID:** BUG-02
- **Severity:** Medium
- **Component:** `jobboard.jac` (`walker:pub PostJob`, `walker:pub AddReview`)
- **Preconditions:** Server running.
- **Reproduction Steps:**
  1. Call `PostJob` with empty `title`, `licence_no`, or `description`.
  2. Call `AddReview` with empty or whitespace `text`.
- **Expected Behavior:** Rejection with HTTP 200 payload containing `ok: False` and informative validation error message.
- **Actual Behavior:** `PostJob` proceeded to external network calls with empty strings; `AddReview` attached blank reviews.
- **Root Cause:** No front-of-walker validation check on string fields.
- **Fix Applied:** Added guard conditions in `jobboard.jac`:
  ```jac
  # In PostJob:
  if not self.title.strip() or not self.licence_no.strip() or not self.description.strip() {
      report PostResult(ok=False, message="Job title, licence number, and description are required.");
      disengage;
  }

  # In AddReview:
  if not self.text.strip() {
      report PostResult(ok=False, message="Review text cannot be empty.");
      disengage;
  }
  ```
- **Regression Test:** `TC-31` in `scripts/comprehensive_test_suite.py`.
- **Retest Result:** **PASS** (Properly rejects empty payloads in 0.01s).
