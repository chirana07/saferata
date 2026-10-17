# SafeRata: Comprehensive Test Plan & Quality Assurance Strategy

**Document Version:** 1.0.0  
**Date:** 2026-10-17  
**System Under Test:** SafeRata Autonomous Civic Trust & Verification Platform  
**Target Environment:** Local Runtime (`jac 0.34.24`, port 8000) & Jac Hammer Cloud Platform  
**Repository:** https://github.com/chirana07/saferata (`main`, commit `e617761`)

---

## 1. Scope & Test Objectives

The primary objective of this quality assurance audit is to empirically validate every layer of the SafeRata system:
1. **Infrastructure & Runtime:** Verify `jac 0.34.24` HTTP daemon, port 8000 binding, ModelPool fallback strategies, and process stability.
2. **UI & Navigation:** Verify responsive rendering across viewports (Desktop 1512px, Mobile 375px), sidebar routing, modals, bookmarking, and interactive comparisons.
3. **API & Backend Integration:** Exercise every `walker:pub` endpoint with valid, boundary, and malicious payloads.
4. **Database & Graph Integrity:** Validate Jaseci object graph nodes (`Job`, `Review`, `Agency`, `Contact`, `Offer`, `Alert`), graph edge traversals, and SQLite WAL persistence.
5. **Security & Civic Guardrails:** Test the live SLBFE government registry gate, quote-matching Critic, anti-hallucination score caps, and privacy protection.
6. **End-to-End Scenarios:** Execute 8 end-to-end realistic user journeys (from job posting and scam detection to side-by-side comparison and community alert dissemination).

---

## 2. Test Architecture & Layer Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│ LAYER E: AUTHENTICATION, CIVIC TRUST & SECURITY INTEGRITY   │
│  - SLBFE Registry Gatekeeper  - Quote-Matching Critic       │
│  - Anti-Hallucination Caps    - Secret & PII Sanitization   │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ LAYER D: DATABASE PERSISTENCE & GRAPH RELATIONAL INTEGRITY  │
│  - Root Graph Traversal       - Edge Attachments (Job->Rev) │
│  - SQLite WAL Durability      - Cross-User Contact Tracking │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ LAYER C: API CONTRACTS & WALKER REQUEST/RESPONSE FLOWS      │
│  - /walker/Investigate        - /walker/PostJob             │
│  - /walker/ListJobs           - /walker/AddReview           │
│  - /walker/ListAgencies       - /walker/RecentChecks        │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ LAYER B: REACTIVE CLIENT UI, ROUTING & VIEWPORT INTEGRATION │
│  - Sidebar & Top Navigation   - Discover & Compare Trays    │
│  - Investigation Input & Stepper - Agency Portal & Modals   │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│ LAYER A: RUNTIME STARTUP, ENVIRONMENT & DEPENDENCY HEALTH   │
│  - jac 0.34.24 Runtime        - ModelPool (Ollama/Gemini)   │
│  - Port 8000 Binding          - Jac Code Share (>=80%)      │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Prioritized Execution Sequence

1. **Priority 1 (Critical Business Safety):** 
   - Live SLBFE licence gate (rejecting unlicensed posters).
   - Scam offer detection (100% detection on trafficking and fake visas).
   - Quote-matching Critic (zero hallucinated red flags).
2. **Priority 2 (Data Integrity & Persistence):**
   - Jaseci graph persistence across restarts.
   - Job and Review node associations (`job ++> review`).
   - Scam number cross-linkage (`Contact` node network guardian).
3. **Priority 3 (End-to-End User Workflows):**
   - Investigation lifecycle (input $\rightarrow$ extraction $\rightarrow$ ReAct $\rightarrow$ courtroom debate $\rightarrow$ verdict card).
   - Civic job board browsing, filtering, LKR currency calculation, and side-by-side comparison modal.
   - Worker review submission and impersonation fraud scoring.
4. **Priority 4 (Reliability, Boundaries & Edge Cases):**
   - Vague offer handling (ReAct `ask_user` interaction).
   - Network failure and offline fallback behavior.
   - Long strings, special characters, and concurrent requests.

---

## 4. Test Environment Specification

- **OS:** macOS (Darwin arm64)
- **Runtime:** `jac 0.34.24` (`~/.local/bin/jac034`)
- **Port:** `8000` (Local daemon)
- **External Integration:** Live SLBFE Government Registry (`applications.slbfe.lk`)
- **Model Fallback:** Primary: Ollama Cloud `gemma4` $\rightarrow$ Secondary: Google Gemini `gemini-2.0-flash` $\rightarrow$ Tertiary: Local Ollama
- **Browser Automation:** Antigravity Browser Subagent / Chromium Headless (1512x804 and 375x812 viewports)
