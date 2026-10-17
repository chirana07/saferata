# SafeRata: Target System Architecture Specification

**Document Version:** 1.0.0  
**Status:** Approved & Implemented  
**Date:** 2026-10-17  
**Repository:** https://github.com/chirana07/saferata (`main`, commit `1116d58`)

---

## 1. Executive Summary

SafeRata is an autonomous civic trust and forensic intelligence platform built to protect Sri Lankan migrant workers from fraudulent employment agencies, human trafficking syndicates, and financial exploitation. 

The architecture leverages **Jaseci & Jac 0.34.24** to unify backend walkers, data graph nodes, multi-agent LLM reasoning (`by llm`), deterministic rule engines, live government scrapers, and reactive client components into a coherent, high-velocity monolith.

```
                          ┌─────────────────────────────────────┐
                          │         CLIENT APPLICATIONS         │
                          │   Jac Native Web UI (Vite / JSX)    │
                          │   Port 8000 (Vite SSR + Tailwind)   │
                          └──────────────────┬──────────────────┘
                                             │ HTTP POST (walker:pub JSON)
                                             ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               JASECI / JAC 0.34 RUNTIME                                │
│                                                                                        │
│   ┌────────────────────────────────────────────────────────────────────────────────┐   │
│   │                               WALKER ENDPOINTS                                 │   │
│   │  /walker/Investigate      /walker/GetDiscoverJobs     /walker/GetCompanies     │   │
│   │  /walker/VerifyReview     /walker/GetSavedJobIds      /walker/GetAlerts        │   │
│   │  /walker/ApplyForJob      /walker/HealthCheck         /walker/SeedData         │   │
│   └──────────────┬──────────────────────────────────────────────┬──────────────────┘   │
│                  │                                              │                      │
│                  ▼                                              ▼                      │
│   ┌───────────────────────────────┐              ┌─────────────────────────────────┐   │
│   │      MULTI-AGENT TEAM         │              │    DETERMINISTIC RULE ENGINE    │   │
│   │  - Extractor (OfferFacts)     │              │  - rules.jac (Hard Flags)       │   │
│   │  - Lead Investigator (ReAct)  │              │  - Critic (Quote Verifier)      │   │
│   │  - Courtroom (Pros/Def/Judge) │              │  - Scorer (Point Aggregator)    │   │
│   │  - Advisor (Action Plans)     │              │  - Safety Caps (+20 max soft)   │   │
│   └──────────────┬────────────────┘              └────────────────┬────────────────┘   │
│                  │                                                │                    │
│                  ▼                                                ▼                    │
│   ┌────────────────────────────────────────────────────────────────────────────────┐   │
│   │                        JASECI PERSISTENT GRAPH DATABASE                        │   │
│   │    Root ──▶ Job ──▶ Review                                                     │   │
│   │     │   ──▶ Agency (SLBFE registry cache)                                      │   │
│   │     │   ──▶ Contact (Phone / Email nodes for cross-offer tracking)             │   │
│   │     │   ──▶ Offer (Previous investigations)                                    │   │
│   │     └───▶ Alert (Proactive push alerts on newly detected syndicates)           │   │
│   └────────────────────────────────────────────────────────────────────────────────┘   │
└───────────────────────┬───────────────────────────────────────────┬────────────────────┘
                        │                                           │
                        ▼                                           ▼
         ┌─────────────────────────────┐             ┌─────────────────────────────┐
         │     EXTERNAL GOVERNMENT     │             │     LLM MODEL POOL          │
         │   SLBFE Registry Scraper    │             │  Primary: Ollama Cloud      │
         │  (applications.slbfe.lk)    │             │  Fallback 1: Google Gemini  │
         │  Real-time HTML parsing     │             │  Fallback 2: Local Ollama   │
         └─────────────────────────────┘             └─────────────────────────────┘
```

---

## 2. Evaluation of Architectural Trade-offs

### A. Monolithic Jaseci Graph Runtime vs. Distributed Microservices
- **Decision:** Single Jaseci / Jac 0.34 application server running embedded graph persistence and walkers.
- **Rationale:** 
  - Microservices (e.g. separate scrapers, separate auth servers, separate vector DBs, message queues) add unacceptable operational friction, latency, and failure modes for a hackathon civic tool.
  - Jac 0.34 treats nodes and walkers as first-class language constructs, allowing graph walks (`visit [-->]`) in memory with transactional persistence.
  - Jac code share must be $\ge 80\%$ (currently **93.5%**). Keeping data structures, business logic, agent prompts, and frontend components in Jac natively satisfies the hackathon constraints cleanly.

### B. Graph Database vs. Relational SQL
- **Decision:** Jaseci Graph Topology (Nodes & Edges) supported by embedded storage.
- **Rationale:**
  - Fraud detection is inherently a graph problem: syndicates change agency names but reuse mobile numbers, Telegram handles, and bank account details.
  - In Jaseci, linking `Offer ─▶ Contact ◀─ Offer` takes O(1) pointer operations. An alert walker can traverse all connected offers when a single contact is flagged as "Danger".
  - Standard relational SQL would require recursive joins across many-to-many tables.

### C. Live Government Register vs. Pre-cached Database
- **Decision:** Hybrid Live-First with Jaseci Graph Caching.
- **Rationale:**
  - Fraudsters exploit stale caches by claiming recent license issuance. Live scraping against `applications.slbfe.lk` guarantees ground truth.
  - If the SLBFE portal is down or slow, the architecture gracefully degrades to cached `Agency` graph nodes with explicit UI notices advising users to call the official 1989 hotline.

### D. Multi-Agent Courtroom vs. Single-Prompt LLM
- **Decision:** Split pipeline: Extractor $\rightarrow$ ReAct Investigator $\rightarrow$ Adversarial Courtroom (Prosecutor vs. Defender $\rightarrow$ Judge) $\rightarrow$ Deterministic Critic.
- **Rationale:**
  - Single-shot LLMs hallucinate red flags or miss subtle contract clauses.
  - The Prosecutor finds every suspicious angle; the Defender tests if it's standard industry practice (e.g. seasonal hospitality visa); the Judge arbitrates.
  - The **Deterministic Critic** drops any flag whose quoted evidence is not a verbatim substring of the input text, completely eliminating hallucinated red flags.

---

## 3. Technology Choices & Stack Specification

| Layer | Selected Technology | Version | Justification |
|---|---|---|---|
| Language & Runtime | `jaclang` | `0.34.24` | Hackathon official environment; native support for graph, walkers, and LLMs. |
| Database Engine | Jaseci Object Graph Engine | `0.34` | Graph traversals for fraud ring detection; automatic node persistence. |
| Web Server | Built-in Jac HTTP/Vite Server | Native | Exposes `walker:pub` REST endpoints on port 8000 with zero external boilerplate. |
| Frontend Engine | Jac JSX Client | `0.34` | Seamless two-way state binding with Jaseci walkers; compliant with 80% Jac metric. |
| Styling | Tailwind CSS | `v4.0` | Ultra-fast CSS utility rendering via `assets/main.css`. |
| LLM Fallback Pool | Ollama Cloud + Gemini | Custom | Zero downtime: auto-fails over from Ollama Cloud (`gemma4`) to Gemini (`gemini-2.0-flash`). |
| External Integration | Python `urllib` & `BeautifulSoup` | Standard | High-speed, dependency-light HTTP scraping of SLBFE portal with timeout handling. |

---

## 4. Component Structure & Data Flows

### A. Investigation Workflow (`/walker/Investigate`)
1. **Intake:** User inputs job advertisement text, WhatsApp screenshots, or contract terms.
2. **Extraction:** `OfferFacts` agent parses structured fields (Country, Agency Name, License No, Salary, Fees, Visa Type, Contacts, Clauses).
3. **Registry Gatekeeper:** Code calls `slbfe.verify_agency(licence_no, agency_name)`.
   - If not found or mismatch $\rightarrow$ Hard Red Flag (+35 to +40 points).
   - If contact mismatch $\rightarrow$ Hard Red Flag (+30 points, Impersonation Warning).
4. **Graph Intelligence Check:** Walker queries `Contact` nodes in Jaseci graph. If previous users flagged this number $\rightarrow$ Community Intelligence flag.
5. **Specialist Agents & Courtroom:**
   - Trafficking Agent inspects transit routes and cyber scam hubs (Thailand/Myanmar/Cambodia/Laos).
   - Contract Agent inspects passport retention, personal account deposits, and salary deductions.
   - Prosecutor & Defender argue points; Judge assigns severity.
6. **Deterministic Scoring:** `rules.jac` validates literal quotes and tallies final risk score (0–100):
   - **0–24:** LOOKS SAFE (Green)
   - **25–59:** BE CAREFUL (Amber)
   - **60–100:** DANGER (Red)
7. **Graph Write & Alert Propagation:** Offer node is saved and linked to Contact nodes. If classified as DANGER, an `Alert` node is broadcast to connected historical contacts.

### B. Civic Job Board & Compare Workflow (`/walker/GetDiscoverJobs`)
1. **Query:** Client requests verified job listings with optional country/category/verified filters.
2. **LKR Currency Conversion:** Real-time exchange rate calculation converts foreign wages (SAR, AED, QAR, KWD, JPY, KRW) to Sri Lankan Rupees (LKR) with take-home pay deductions.
3. **Interactive Side-by-Side Comparison:** 
   - Users select up to 3 jobs.
   - Jac native modal renders comparative matrix: Net Pay (LKR), Recruitment Fees, Visa Category, Contract Term, Food & Accommodation, Safety Assessment, and SLBFE License Status.

---

## 5. Security & Authentication Model

1. **Zero-Friction Civic Access (`walker:pub`):**
   - Vulnerable migrant workers often lack technical sophistication or institutional email accounts. Requiring upfront account creation causes high drop-off.
   - All investigation and discovery walkers are configured as public (`walker:pub`) with built-in rate-limiting and query sanitization.
2. **Local Session Persistence:**
   - Saved bookmarks and comparison trays use client `localStorage` (`saferata.saved`, `saferata.compare`), preserving user privacy without server-side tracking.
3. **Data Privacy & Sanitization:**
   - Personally identifiable worker information is scrubbed before LLM prompt transmission.
   - Only agency details, contact numbers, and job contract clauses are stored in the graph.
4. **Secret Management:**
   - API keys (`OLLAMA_API_KEY`, `GEMINI_API_KEY`) are injected exclusively via environment variables and never exposed to client bundles or browser logs.

---

## 6. Deployment & Operations Architecture

### A. Local Development
```bash
export LC_ALL=en_US.UTF-8
set -a; source "/Users/chirana/IdeaProjects/EE AI hackathon/.env"; set +a
jac034 start --port 8000 main.jac
```

### B. Jac Hammer Cloud Deployment (`jachammer.ai`)
- **Target Platform:** Jac Hammer Serverless Container Runtime.
- **Runtime Spec:** `jac 0.34.24`.
- **Environment Variables:**
  - `OLLAMA_API_KEY`
  - `GEMINI_API_KEY`
- **Port:** `8000` (auto-detected by platform).
- **Health Check Endpoint:** `http://localhost:8000/walker/HealthCheck`.
