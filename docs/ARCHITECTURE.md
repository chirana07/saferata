# SafeRata: architecture (working name)

**Problem.** Every year many thousands of Sri Lankans go abroad for work. Fake agencies, illegal fees, visit visas sold as work visas, passport-holding clauses and trafficking (for example fake IT jobs in Thailand that end in Myanmar scam compounds) cost people their savings and sometimes their freedom.

**Product.** Paste a job offer: a Facebook ad, a WhatsApp message from an "agent", or contract text. A team of agents investigates it and returns:
- a verdict with a score breakdown
- each red flag, with the exact words quoted from the offer
- what to ask the agency, and the next steps (the SLBFE 1989 hotline, a ready report draft)
- the sources used, with timestamps

## Agent team (it is an investigation, not a pipeline)

```
offer text
   │
   ▼
Extractor ── by llm ──▶ OfferFacts (job, country, salary, fees, agency, licence no, visa, contacts, clauses)
   │
   ▼
Lead Investigator ── ReAct loop, by llm(tools=[...]) ── chooses its own next step:
   │     lookup_licence()        live SLBFE register, by licence number
   │     lookup_agency_name()    live SLBFE register, by name
   │     check_contacts()        do the offer's phones/emails match the agency's REGISTERED ones? (impersonation)
   │     community_reports()     graph walk: Contact ◀── other Offers (shared intelligence)
   │     country_rules()         SLBFE guidance + country notes
   │     ask_user(question)      pauses the run and asks the person for a missing fact
   ▼
Specialist router ── by llm picks experts from the findings ──▶ Trafficking / Contract clauses / Fees & payment
   │
   ▼
Prosecutor (argues scam)  ⟷  Defender (argues genuine)  ──▶  Judge (decides which soft flags stand)
   │
   ▼
Critic (deterministic): drops any flag whose evidence is not literally in the offer
   │
   ▼
Scorer (deterministic points per flag) ──▶ Advisor (questions to ask, next steps, report draft)
   │
   ▼
Graph write: Offer ─▶ Agency, Offer ─▶ Contact; alert walker notifies earlier offers that share a contact
```

Every agent action is appended to `steps` and shown live in the UI's **agent activity panel**.

## Trust levels (strongest first)

| Level | Source | Decides |
|---|---|---|
| 1. Official, live | SLBFE licensed-agency register (applications.slbfe.lk) | Whether the agency is licensed, its registered phones and email, and its licence expiry date |
| 2. Official rules | SLBFE public guidance (don't pay or hand over your passport before verifying; register before departure; work visa; receipts; 1989 hotline) | Hard flags, applied by code |
| 3. Community | Earlier checks saved in the graph | Context only ("2 other people…"), never a verdict on its own |
| 4. LLM judgement | The agents | Extraction and soft signals; every flag must quote its evidence |

- **The LLM never decides licence status.** Only the register can say that. If the register can't be reached, the app says "could not verify, call 1989".

## Scoring (transparent, deterministic)

**Hard flags:**

| Flag | Points |
|---|---|
| Agency not on the register | +40 |
| Licence number doesn't match the agency name | +35 |
| Contact not among the agency's registered contacts (possible impersonation) | +30 |
| Visit or tourist visa offered for a job | +30 |
| Payment to a personal account / payment before a contract | +25 |
| Passport retention | +25 |
| Trafficking pattern | +35 |

**Soft flags** (from the LLM, each must quote evidence) score +5 to +10 each, capped at +20 in total.

**Bands:**
- 0–24: **Looks safe**
- 25–59: **Be careful**
- 60 or more: **Danger**

## Graph

```
Root ─▶ Offer ─▶ Agency (licence_no, registered phones, valid_upto, checked_at)
          │ ─▶ Contact (normalised phone or email) ◀─ Offer (other users)
          └─▶ Alert (created when a linked offer is later judged as Danger)
```

All endpoints are `walker:pub`, so every visitor shares one guest graph. This is how community intelligence works with no login.

## Modules

| File | Purpose |
|---|---|
| `models.jac` | Model pool: Ollama cloud, then Gemini, then local models |
| `slbfe.jac` | Live register lookup and HTML parser |
| `graph.jac` | Nodes, edges and `sem` |
| `rules.jac` | Deterministic flags, critic and scorer |
| `agents.jac` | The `Investigate` walker and all `by llm` agents |
| `frontend.jac` | Paste box, activity panel, verdict card |
| `tests/` | Evaluation set of sample offers with expected verdicts |
