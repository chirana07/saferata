# SafeRata: Feature Inventory & Functional Mapping

**Document Version:** 1.0.0  
**Date:** 2026-10-17 14:33 UTC+5:30  
**Target Environment:** Local Jac Server (`http://localhost:8000`), `jac 0.34.24` (`~/.local/bin/jac034`)  
**Repository:** https://github.com/chirana07/saferata (`main`, commit `1116d58`)

---

## 1. Feature Classification & Inventory Table

| Feature ID | Module / Screen | Intended Behavior | Implementation Status | Tech Dependencies | Verification Evidence |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **F-01** | **Investigate** | User pastes raw advert/contract; 10 agents extract terms, query SLBFE, calculate risks, run courtroom debate, and assign 0-100 risk band. | **Implemented & Verified** | `walker:pub Investigate`, `ModelPool`, `slbfe.jac`, `rules.jac` | Verified via `evals.jac` (Case 1: DANGER 100) & `api_e2e.py`. |
| **F-02** | **Investigate: Follow-up Q&A** | When advert lacks visa/fee clarity, agent responds with `needs_input` questions; worker inputs answers to finalize verdict. | **Implemented & Verified** | `Investigate(answers=...)` | Verified via `api_e2e.py` (Saudi driver follow-up flow: `PASS after answers -> verdict`). |
| **F-03** | **Investigate: Scenario Chips** | One-click chips populate the input with realistic scam/genuine samples (Thailand scam, impersonation, WhatsApp, genuine). | **Implemented & Verified** | Local component state (`Check.jac:8-13`) | Tested in browser session across all 4 sample templates. |
| **F-04** | **Investigate: SLBFE Section 62 Export** | Formats legal complaint draft under Sec 62 of SLBFE Act No. 21 of 1985; one-click copy to clipboard with feedback. | **Implemented & Verified** | `navigator.clipboard`, `outcome.advice.report_draft` | Verified in browser UI; clipboard captures pre-formatted complaint. |
| **F-05** | **Discover: Job Retrieval** | Lists verified jobs from licensed agencies with risk scores, take-home calculations, and country tags. | **Implemented & Verified** | `walker:pub ListJobs`, `Job` nodes | Verified in `test_all_walkers.py`; 7 active listings returned from graph. |
| **F-06** | **Discover: Keyword Search** | Real-time text filter matching job title, destination country, occupation, or description. | **Implemented & Verified** | Client-side reactive filter on `jobs` | Verified in browser with queries "driver", "Qatar", "welder". |
| **F-07** | **Discover: Multi-Field Filters** | Filters listings by destination, occupation group, minimum salary (LKR), experience level, and contract type. | **Implemented & Verified** | Client-side reactive filter | Tested in browser UI; correctly reduces results grid. |
| **F-08** | **Discover: Sort Modes** | Sorts by Highest Salary, Most Recent (reverse `posted_at`), and Relevance/Suitability. | **Implemented & Verified** | Client-side comparator functions | Verified in `Discover.jac:273-281`; explicit handlers for salary, recent, suitability. |
| **F-09** | **Discover: Job Detail Modal** | Displays full job dossier: safety findings with literal quotes, wage take-home breakdown, visa rules, agency record, and community reports. | **Implemented & Verified** | In-memory `JobView`, `FindingView` | Verified in browser; all 6 forensic sections render accurately. |
| **F-10** | **Discover: Save Jobs (Bookmarking)** | Worker bookmarks jobs with bookmark button; filtered with "Saved" toggle pill on search bar; persisted in browser. | **Implemented & Verified** | `localStorage` (`saferata.saved`), `Discover.jac:10-25` | Ported from teammate's branch into native Jac; verified in browser. |
| **F-11** | **Discover: Compare Jobs** | Side-by-side comparison modal for up to 3 jobs; compares salary, LKR net, fees, visa, contract, housing, safety score, match, and SLBFE status. | **Implemented & Verified** | `localStorage` (`saferata.compare`), `Discover.jac:25-35` | Ported from teammate's branch into native Jac; verified in browser. |
| **F-12** | **Discover: Pre-Payment Advice** | "Enquire" button toggles a 3-question guidance checklist workers must ask the agency before making payments. | **Implemented & Verified** | Local component state | Tested in browser UI. |
| **F-13** | **Discover: Worker Review Submission** | Worker submits fraud or positive experience report with receipt evidence; assessed by Review Verifier agent. | **Implemented & Verified** | `walker:pub AddReview`, `Review Verifier` | Verified in `api_e2e.py`; agency score preserved on impersonation, increased on direct fraud. |
| **F-14** | **Discover: Agency Reply to Review** | Licensed agency publishes official clarification under a worker review. | **Implemented & Verified** | `walker:pub RespondToReview` | Verified in `test_all_walkers.py`; response attached to `Review` node. |
| **F-15** | **Discover: Request Correction** | Public or agency flags factual error on listing; logged on job node for moderation. | **Implemented & Verified** | `walker:pub RequestCorrection` | Verified in `test_all_walkers.py`; logged to `job.corrections`. |
| **F-16** | **Companies: Directory & Status** | Directory of registered SLBFE agencies with license validity, registered phone numbers, and known impersonator numbers. | **Implemented & Verified** | `walker:pub ListAgencies`, `Agency` nodes | Verified in `test_all_walkers.py`; ATC Global returned with license 3500. |
| **F-17** | **Companies: Profile Reporting** | Worker submits report or correction from company profile page; links to active listings with fallback guards. | **Implemented & Verified** | `walker:pub AddReview`, `Companies.jac:51-65` | Verified with validation guards for empty listings and required fields. |
| **F-18** | **Agency Portal: Job Submission** | Agency submits new job; validates license against live SLBFE register and runs multi-agent risk assessment. | **Implemented & Verified** | `walker:pub PostJob`, `slbfe.jac` | Verified: genuine job posted (`LOOKS SAFE`); fake license `9998` rejected. |
| **F-19** | **Agency Portal: Dispute Findings** | Agency disputes agent-judgement findings; Appeal Reviewer agent re-evaluates claims. | **Implemented & Verified** | `walker:pub AppealFinding` | Verified: official SLBFE findings rejected; agent-judgement appeals accepted. |
| **F-20** | **Agency Portal: Document Upload** | Upload demand letters / contract PDFs for automated document analysis. | **Partially Implemented** | Local component state (`files: list[str]`) | Only filenames captured; explicitly marked: *"Only file names are kept: document upload not built yet."* |
| **F-21** | **Profile: Local Work Profile** | Candidate enters occupation, skills, experience, and salary preferences; feeds `MatchJobs` calculation. | **Implemented & Verified** | `localStorage` (`saferata.p.*`), `walker:pub MatchJobs` | Verified: `MatchJobs returned 7 matches`; match % and reasons display on job cards. |
| **F-22** | **Community Feed** | Graph-wide feed of recently investigated offers with Network Guardian alerts for cross-checked scam phone numbers. | **Implemented & Verified** | `walker:pub RecentChecks`, `Contact` nodes | Verified in `api_e2e.py` (returned 10 historical checks from graph). |

---

## 2. Feature-to-Backend Architecture Mapping

```
[UI Screen / Component]   ──(root spawn)──▶  [Walker Endpoint]  ──(graph walk)──▶  [Jaseci Nodes]
CheckOffer (Check.jac)    ────────────────▶  Investigate        ────────────────▶  Offer, Contact, Alert
Discover (Discover.jac)   ────────────────▶  ListJobs           ────────────────▶  Job, Review, Agency
Discover (Discover.jac)   ────────────────▶  MatchJobs          ────────────────▶  Job (in-memory fit)
Discover Review Form      ────────────────▶  AddReview          ────────────────▶  Job ++> Review
Discover Correction Form  ────────────────▶  RequestCorrection  ────────────────▶  Job.corrections
Companies (Companies.jac) ────────────────▶  ListAgencies       ────────────────▶  Agency, Contact
AgencyPortal (Agency.jac) ────────────────▶  PostJob            ────────────────▶  Agency ++> Job
AgencyPortal (Agency.jac) ────────────────▶  AppealFinding      ────────────────▶  Job.appeals
CommunityFeed (Feed.jac)  ────────────────▶  RecentChecks       ────────────────▶  Offer, Alert
```
