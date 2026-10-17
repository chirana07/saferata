# SafeRata: Comprehensive Test Case Catalog

**Document Version:** 1.0.0  
**Date:** 2026-10-17  
**Total Test Cases:** 36

---

## Layer A: Startup, Infrastructure & Runtime

| ID | Title | Precondition | Input / Action | Expected Result | Status |
|---|---|---|---|---|---|
| **TC-01** | Port 8000 Binding | Server started | `curl -s http://localhost:8000/` | HTTP 200 returned with Jac JSX frontend assets | PASS |
| **TC-02** | Jac Runtime Version | Local toolchain | `~/.local/bin/jac034 --version` | Exactly `jac 0.34.24` executed | PASS |
| **TC-03** | Jac Code Share | Source directory | `bash scripts/jac-ratio.sh .` | Code share $\ge 80\%$ (Actual: 93.5%) | PASS |
| **TC-04** | Syntax & Type Check | Codebase files | `jac034 check main.jac frontend.jac components/*.jac` | 0 syntax errors across all 9 modules | PASS |
| **TC-05** | ModelPool Fallback | Env vars loaded | Trigger LLM call with primary key | Fallback chain active: Ollama $\rightarrow$ Gemini $\rightarrow$ Local | PASS |

---

## Layer B: Reactive UI, Routing & Interaction

| ID | Title | Precondition | Input / Action | Expected Result | Status |
|---|---|---|---|---|---|
| **TC-06** | Sidebar Navigation | Desktop viewport | Click "Discover", "Investigate", "Companies", "Profile" | Active tab switches without page reload; URL/state synchronized | PASS |
| **TC-07** | Job Details Modal | Discover tab | Click on a job card | Modal slides up with full terms, deductions, salary, and SLBFE badge | PASS |
| **TC-08** | Bookmark Persistence | Discover tab | Click Bookmark icon on a job card | Job ID saved in `localStorage.saferata.saved`; "Saved (1)" filter toggles it | PASS |
| **TC-09** | Side-by-Side Compare | Discover tab | Select 2–3 jobs, click "Compare (N)" | Modal renders side-by-side comparison matrix with net pay in LKR | PASS |
| **TC-10** | Mobile Responsive Viewport | Viewport 375x812 | Inspect mobile header and layout | Sidebar collapses into mobile top bar with agency portal shortcut | PASS |

---

## Layer C: API Contracts & Walker Integration

| ID | Title | Precondition | Input / Action | Expected Result | Status |
|---|---|---|---|---|---|
| **TC-11** | Scam Investigation API | Server running | POST `/walker/Investigate` with Thailand cyber scam ad | Returns DANGER verdict (100/100) with quoted evidence | PASS |
| **TC-12** | Interactive Clarification | Server running | POST `/walker/Investigate` with vague driver ad | Status `needs_input` with targeted questions returned | PASS |
| **TC-13** | Answer Follow-up | Vague ad active | POST `/walker/Investigate` with answers array | Follow-up processed; returns final score & band | PASS |
| **TC-14** | Legitimate Job Post | Licence 3500 valid | POST `/walker/PostJob` with genuine ATC job | Returns `ok=True`, job node created, band `LOOKS SAFE` | PASS |
| **TC-15** | Fake Licence Rejection | Licence 9998 fake | POST `/walker/PostJob` with invalid licence | Returns `ok=False`, message explains licence not on SLBFE register | PASS |
| **TC-16** | Impersonation Review | Job node active | POST `/walker/AddReview` with scam phone 0769998877 | Job score unchanged; warning added naming scam phone | PASS |
| **TC-17** | Direct Fraud Review | Job node active | POST `/walker/AddReview` with official office fee receipt | Agency score re-evaluated upwards; review marked `credible` | PASS |
| **TC-18** | Recent Checks Feed | Offers in graph | POST `/walker/RecentChecks` | Returns list of historical checks with bands and scores | PASS |

---

## Layer D: Database Persistence & Graph Integrity

| ID | Title | Precondition | Input / Action | Expected Result | Status |
|---|---|---|---|---|---|
| **TC-19** | Graph Node Creation | Server running | Post new Job via walker | New `Job` node created in memory & committed to SQLite WAL | PASS |
| **TC-20** | Relational Edge Attachment | Job node exists | Post Review via `AddReview` | `job ++> review` edge created and retrievable via `[job -->[?:Review]]` | PASS |
| **TC-21** | Disk WAL Persistence | Entity written | Inspect `.jac/data/anchor_store.db-wal` | Physical SQLite database file updated on disk (>1.6 MB) | PASS |
| **TC-22** | Contact Node Linking | Scam phone in offer | Investigate offer with new phone | `Contact` node created and linked to `Offer` node | PASS |
| **TC-23** | Network Guardian Alert | Contact linked | Second user submits Danger offer with same phone | Alert node created and linked to earlier offers sharing phone | PASS |

---

## Layer E: Authentication, Trust & Civic Security

| ID | Title | Precondition | Input / Action | Expected Result | Status |
|---|---|---|---|---|---|
| **TC-24** | SLBFE Gate Enforcement | Live register active | Query `slbfe.verify_agency(3500)` | Official record parsed: A T C GLOBAL HOLDINGS, registered phones | PASS |
| **TC-25** | Unlicensed Agent Gate | Unregistered entity | Query `slbfe.verify_agency(9999)` | Returns `found=False`; strictly blocks agency self-registration | PASS |
| **TC-26** | Quote-Matching Critic | LLM output generated | Subjective soft flag generated | Critic drops any flag whose quote is not a literal substring of offer | PASS |
| **TC-27** | Anti-Hallucination Cap | Multiple soft flags | Scorer aggregates points | Soft LLM flags strictly capped at maximum +20 points | PASS |
| **TC-28** | Zero Credential Leakage | API & Logs inspect | Search stdout/stderr and responses | No raw `OLLAMA_API_KEY` or `GEMINI_API_KEY` printed or exposed | PASS |

---

## Realistic End-to-End Scenarios

| ID | Scenario | Scope | Expected Outcome | Status |
|---|---|---|---|---|
| **TC-29** | **Scenario 1: Complete Happy Path** | Job Post $\rightarrow$ Listing $\rightarrow$ Investigation $\rightarrow$ Save $\rightarrow$ Compare | Complete vertical slice functional from end to end | PASS |
| **TC-30** | **Scenario 2: Multi-Role Experience** | Job Seeker vs Licensed Agency vs System Guardian | Agency posts with licence gate; worker bookmarks/reviews | PASS |
| **TC-31** | **Scenario 3: Input Validation** | Empty fields, negative fees, extreme text lengths | Safe rejection with descriptive error notices; no crash | PASS |
| **TC-32** | **Scenario 4: Failure & Recovery** | Malformed payloads, missing IDs, unverified queries | Graceful degradation with clear user feedback | PASS |
| **TC-33** | **Scenario 5: Concurrency** | Simultaneous walker calls to `ListJobs` & `Investigate` | Both requests complete cleanly without database lock errors | PASS |
| **TC-34** | **Scenario 6: Reporting Accuracy** | LKR currency conversion & take-home pay calculations | Accurate math: deductions subtracted, converted at live rate | PASS |
| **TC-35** | **Scenario 7: Entity Lifecycle** | Creation, update via review, retrieval via graph walk | Node states accurately track lifecycle transitions | PASS |
| **TC-36** | **Scenario 8: Responsive Layout** | Desktop (1512px) vs Mobile (375px) | Layout adapts cleanly with zero horizontal overflow | PASS |
