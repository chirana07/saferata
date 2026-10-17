# SafeRata: check a foreign job offer before you pay

**AI Hackathon 2026 (Jaseci) · Built in Jac 0.34.24 · 93.5% Jac Codebase**

Every year many thousands of Sri Lankans pay recruiters for jobs abroad. Some meet:
- unlicensed agents
- scammers using a real agency's name
- visit visas sold as work visas
- fees paid into personal accounts
- trafficking into scam compounds

SafeRata is an **autonomous team of AI agents** that investigates a job offer against the **official SLBFE licensed-agency register (live)**, argues the case for and against in a multi-agent courtroom debate, and tells the worker what to do before they pay.

> **Primary App (`main`):** 100% Native Jac full-stack application (`main.jac` + Jac JSX frontend) running on port 8000.  
> **Companion React UI:** Preserved on branch [`companion/web-ui`](https://github.com/chirana07/saferata/tree/companion/web-ui) as an alternative client connecting to the Jac API.  
> **Evaluation & Verification:** 19/19 unit tests, 11/11 E2E API checks, 8/8 evaluation scenarios passing. Live register verified.

## What it does

| Feature | What happens |
|---|---|
| **Check an offer** | Paste a Facebook ad, a WhatsApp message or a contract. You get a verdict (Looks safe, Be careful or Danger) with a transparent score, each red flag with the exact words quoted, a prosecutor vs defender debate, questions to ask the agency, next steps, a ready-made report for the SLBFE 1989 hotline, and timestamped sources. |
| **Verified job board** | Agencies can post only if their licence is on the live SLBFE register. Every posting is investigated automatically and shows its risk badge. |
| **Evidence-backed reviews** | Workers report fraud with evidence. A **Review Verifier** agent scores credibility. Credible reports re-score the job and **alert earlier users linked by the same phone number**. |

## The agent team (an investigation, not a pipeline)

```
Extractor ─▶ Lead Investigator (ReAct: chooses its own tools, may ASK the person)
                 tools: live SLBFE register · contacts vs registered ones · community graph · country notes · ask_user
             ─▶ picks Specialists (Trafficking / Contract / Fees)        [run in parallel]
             ─▶ Rules engine + Critic (drops any flag without a verbatim quote)
             ─▶ Prosecutor vs Defender ─▶ Judge                            [parallel debate]
             ─▶ Scorer (fixed points) ─▶ Advisor ─▶ Network Guardian (graph alerts)
```

**Trust:** the LLM never decides licence status or points. The live register and the code do.

| Level | Source |
|---|---|
| 1 | Live SLBFE register |
| 2 | SLBFE rules |
| 3 | Community graph (context only) |
| 4 | Agent judgement (must quote evidence, capped at 20 points) |

## How we used Jac and Jaseci

| Jac feature | Where |
|---|---|
| `walker:pub` endpoints | `Investigate`, `PostJob`, `ListJobs`, `AddReview`, `RecentChecks` |
| Walker methods as `by llm(tools=[...])` tools | The Lead Investigator's ReAct tools log every step to the UI |
| Typed `by llm()` functions + `sem` | Extractor → `OfferFacts`, specialists → `list[SoftFlag]`, Judge → `JudgeRuling`, Advisor → `Advice`, Review Verifier → `ReviewAssessment` |
| Persistent graph | `Offer`, `Agency`, `Contact`, `Job`, `Review`, `Alert` nodes. Shared `Contact` nodes link scams across users |
| Graph traversal | Danger verdicts and credible fraud reviews walk `Contact <-- Offer` to leave `Alert`s |
| `ModelPool` fallback | Ollama Cloud, then Gemini, then local Ollama |
| Python interop | Live register lookup with `urllib` / `re` / `html` |
| Jac client (JSX) | `frontend.jac` and `components/Board.jac` call walkers with `root spawn` |

## Files

| File | Purpose |
|---|---|
| `slbfe.jac` | Live SLBFE register search and parser |
| `graph.jac` | Nodes and the typed objects the agents fill (with `sem`) |
| `rules.jac` | Official-rule flags, evidence critic, deterministic scorer (+ unit tests) |
| `agents.jac` | `Investigate` walker: the whole agent team |
| `jobboard.jac` | Job board, reviews, Review Verifier (impersonation vs agency fraud) |
| `frontend.jac`, `components/Board.jac` | UI |
| `evals.jac` | Labelled sample offers, with an accuracy report |
| `scripts/api_e2e.py` | End-to-end API checks for every backend flow |

## Run locally (jac 0.34.24)

```bash
export OLLAMA_API_KEY=...   # and/or GEMINI_API_KEY=...
export LC_ALL=en_US.UTF-8
jac install
jac start                         # app + API on http://localhost:8000
jac test rules.jac                # unit tests (rules, critic, scorer)
jac test agents.jac               # unit tests (agency-name matching)
jac run evals.jac                 # agent accuracy on labelled offers (live models)
python3 scripts/api_e2e.py        # 11 end-to-end backend checks against the running server
```

## Limitations (honest)

- **Job board identity:** we check that the licence exists, not that the person posting works for that agency. Next step: a one-time code sent to the agency's registered phone.
- **Expired licences:** the register lists only valid agencies, so "not found" can't tell an expired licence from a fake one.
- **Fee caps:** we couldn't find a current official table of fee caps, so we flag how fees are paid, not the amounts.
- **Language:** English only for now. Sinhala and Tamil come next.
