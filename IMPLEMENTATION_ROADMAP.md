# SafeRata: Implementation Roadmap & Execution Sequence

**Target Deadline:** AI Hackathon 2026 Submission Window (17:15 – 17:30 UTC+5:30, 17 Oct 2026)  
**Current Milestone:** Checkpoint A Completed (Architecture, Feature Inventory & Implementation Roadmap)  
**Repository:** https://github.com/chirana07/saferata (`main`, commit `1116d58`)

---

## 1. Sequence & Prioritization Matrix

```
[Phase 1: Discovery & System Audit]        ──▶  STATUS: COMPLETED (SYSTEM_AUDIT.md, FEATURE_INVENTORY.md)
              │
              ▼
[Phase 2 & 3: Target Architecture]         ──▶  STATUS: COMPLETED (ARCHITECTURE.md, Jaseci Graph Topology)
              │
              ▼
[Phase 4: Database Design & Migrations]    ──▶  STATUS: COMPLETED (DATABASE_DESIGN.md, Graph Models)
              │
              ▼
[Phase 5 & 6: Foundation & Security Gate]  ──▶  STATUS: COMPLETED (SLBFE HTTPS Gate, Quote Critic)
              │
              ▼
[Phase 7 & 8: Feature Synthesis & Fixes]   ──▶  STATUS: COMPLETED (Native Save & Compare, Form Guards)
              │
              ▼
[Phase 9 & 10: Regression Verification]    ──▶  STATUS: IN PROGRESS (19/19 Unit Tests, 11/11 E2E, 8/8 Evals)
              │
              ▼
[Phase 11: Jac Hammer Deployment]          ──▶  STATUS: READY FOR EXECUTION (jachammer.ai, jac 0.34.24)
              │
              ▼
[Phase 12: Video Demo & Final Submission]  ──▶  STATUS: READY (docs/DEMO_SCRIPT.md, 17:15 - 17:30)
```

---

## 2. Detailed Milestone Deliverables

### Milestone 1: Core System Hardening (Completed)
- [x] Fast-forward `main` to unified commit `1116d58`.
- [x] Implement native **Save Jobs** bookmarking and search bar filter in `Discover.jac`.
- [x] Implement native **Compare Jobs** side-by-side modal in `Discover.jac`.
- [x] Protect the $\ge 80\%$ Jac code rule in `scripts/jac-ratio.sh` (Current: **93.5% Jac**).
- [x] Repair empty-review, empty-correction, and empty-agency-listing edge cases in `Discover.jac` and `Companies.jac`.
- [x] Synchronize backup status in `SAFERATA_PROJECT_BACKUP.md`.

### Milestone 2: Pre-Submission Regression Verification (In Progress)
- [x] Jac component syntax check: `jac034 check main.jac frontend.jac components/*.jac` (9/9 passed).
- [x] Unit test suite: `jac034 test rules.jac agents.jac` (19/19 passed in 9.57s).
- [x] End-to-end API regression: `python3 scripts/api_e2e.py` (11/11 passed).
- [ ] Live evaluation benchmark: `jac034 run evals.jac` (In progress, 4/8 cases verified).
- [ ] Database clean & re-seed test: `jac034 clean --data --force` followed by `seed.jac` to verify fresh deployment startup.

### Milestone 3: Jac Hammer Production Deployment (Target: 15:30 – 16:30)
- [ ] Import `chirana07/saferata` repository into [jachammer.ai](https://jachammer.ai).
- [ ] Select branch `main`.
- [ ] Pin Jac Runtime to **`0.34.24`**.
- [ ] Configure environment variables: `OLLAMA_API_KEY` and `GEMINI_API_KEY`.
- [ ] Verify preview execution: test Thailand scam offer in Investigate preview.
- [ ] Click **Publish** and copy public production URL.
- [ ] Append live Jac Hammer URL to `README.md` and commit to `main`.

### Milestone 4: Demonstration Video Recording (Target: 16:30 – 17:00)
- [ ] Record a 3-minute video walkthrough following [docs/DEMO_SCRIPT.md](file:///Users/chirana/IdeaProjects/saferata/docs/DEMO_SCRIPT.md).
- [ ] Highlight the 4 core pillars:
  1. High-risk scam analysis (Thailand IT job $\rightarrow$ DANGER 100 with Courtroom debate cards).
  2. Live SLBFE register gate check (ATC Global vs fake license).
  3. Pre-screened job board with take-home pay, LKR conversion, and the newly built **Compare** feature.
  4. Evidence-backed review moderation (Review Verifier catching impersonation phone numbers).
- [ ] Upload video as unlisted on YouTube.

### Milestone 5: Submission Window Execution (Window: 17:15 – 17:30)
- [ ] GitHub Repository URL: `https://github.com/chirana07/saferata`
- [ ] Live Jac Hammer App URL: `https://<app>.jachammer.ai`
- [ ] Demo Video URL: YouTube link
- [ ] Written Summary: "How we used Jac & Jaseci" (from `README.md`).
