# SafeRata: handoff for coding agents

Read this before changing anything. It is the single source of truth for how to work in this repo.

## What this is

SafeRata is a multi-agent app for **AI Hackathon 2026 (Jaseci)**. A worker pastes a foreign job offer; a team of AI agents investigates it against the **live SLBFE licensed-agency register** and returns a verdict with quoted evidence. It also includes a verified job board with evidence-backed reviews.

- **Repo:** https://github.com/chirana07/saferata (public)
- **Hackathon rules:** at least 80% of the code must be Jac (currently ~98%; check with the line count below). All coding happens during hacking hours (until 17:30, 17 Oct 2026).
- **Design docs:** `docs/ARCHITECTURE.md`, `docs/BUILD_PLAN.md` (status and next steps), `docs/EVAL_RESULTS.md`, `docs/PROPOSAL.md`.

## Toolchain: jac 0.34.24 (required by the organisers)

- **Use jac 0.34.24, not 0.37.** `jac.toml` pins `jac-version = "==0.34.24"`.
- **On this Mac,** the 0.34 binary is `~/.local/bin/jac034`. `~/.local/bin/jac` is the old 0.37.25, so don't use it.
- **On another machine,** download `jac-0.34.24-<platform>` from https://github.com/jaseci-labs/jaseci/releases/tag/v0.34.24 and verify the `.sha256`.
- **Reference guides:** `jac034 guide <name>` (e.g. `jac034 guide jac-by-llm`). Trust these over web docs or memory.
- **Start of every shell:** `export LC_ALL=en_US.UTF-8`. Without it, the embedded Postgres fails to start.

### Secrets (not in the repo)

The app needs `OLLAMA_API_KEY` and/or `GEMINI_API_KEY` in the environment. On this Mac they are in `/Users/chirana/IdeaProjects/EE AI hackathon/.env`:

```bash
set -a; source "/Users/chirana/IdeaProjects/EE AI hackathon/.env"; set +a
```

Never commit or print them.

## Commands

```bash
jac034 install                      # after cloning or changing jac.toml
jac034 check <file.jac> [...]       # needs file paths on 0.34; check every file you touch
jac034 test rules.jac               # unit tests: rules, critic, scorer, pattern extraction
jac034 test agents.jac              # unit tests: agency-name matching
jac034 start --port 8000            # serve app + API (0.34 has no `run --port`)
jac034 run seed.jac                 # load demo data via the API (after `jac034 clean --data --force` + restart)
jac034 run evals.jac                # 8 labelled offers through the live agents (expect 8/8)
python3 scripts/api_e2e.py          # 11 end-to-end API checks against the running server (expect 11/11)
bash "/Users/chirana/IdeaProjects/EE AI hackathon/scripts/jac-ratio.sh" .   # Jac share, must stay >= 80%
```

After moving declarations between modules, run `rm -rf .jac/cache`, because 0.34 keeps stale schema caches.

## Files

| File | Purpose |
|---|---|
| `slbfe.jac` | Live SLBFE register search (by licence number or name) and its HTML parser |
| `graph.jac` | Persistent nodes: `Agency`, `Contact`, `Offer`, `Alert` |
| `rules.jac` | Deterministic layer: `RedFlag`, scoring bands, evidence critic, de-duplication, country guidance, pattern extraction (`find_phones`, `find_licence`, …) + tests |
| `agents.jac` | The agent team: the `by llm` schema types (`OfferFacts`, `SoftFlag`, `Advice`, …), the agents (Extractor, specialists, Prosecutor, Defender, Judge, Advisor), and the `Investigate` walker (Lead Investigator ReAct tools, supervisor, graph save, Network Guardian alerts) |
| `jobboard.jac` | `PostJob` (live licence gate + auto-analysis), `ListJobs`, `AddReview` (Review Verifier: impersonation vs fraud by the agency itself) |
| `models.jac` | `ModelPool`: Ollama Cloud gemma4, then Gemini, then local Ollama |
| `main.jac`, `frontend.jac` | Client shell: top nav with Discover · Check an offer · Companies · Agency portal |
| `components/Check.jac`, `Discover.jac`, `Companies.jac`, `Agency.jac`, `Feed.jac` | Screens rebuilt in Jac from the layout-coder design (github.com/Denuwan392/layout-coder). Features the backend lacks show a dashed "not built yet" chip; see `docs/UI_FEATURE_MAP.md` |
| `components/theme.cl.jac` | Design tokens. Pinned client-side (`.cl.jac`); in 0.34, client modules export only `:pub` globals and defs |
| `evals.jac`, `scripts/api_e2e.py`, `try_case.jac` | Evaluation set, API end-to-end checks, CLI helper (`jac034 run try_case.jac samples/x.txt`) |

## Design rules (do not break)

- **The LLM never decides licence status or points.** The register lookup and `rules.jac` do. Every agent flag must quote the offer word for word, or the critic drops it.
- **Agent judgement is capped at +20 points.** Bands: 0–24 Looks safe, 25–59 Be careful, 60+ Danger.
- **Registered agency phone numbers are never linked into the community scam graph.** Re-checks of the same text don't count as community evidence.
- **Endpoints are `walker:pub`,** which means one shared guest graph. That shared graph is what powers the community features.

## jac 0.34 pitfalls (each one was hit and verified)

1. **`by llm` return types:** declare them (objs and enums) in the same module as the `by llm` function. Imported schema types crash with `'str' object has no attribute 'fields'`.
2. **Optional walker fields:** a walker `has x: T | None = None` becomes a required request field (HTTP 422). Keep internal state in an obj field declared `has st: State postinit;` plus `def postinit { self.st = State(); }`.
3. **Client components** need an explicit `return <jsx>;`.
4. **Module names:** avoid names that shadow Python modules. `board.jac` broke client imports, hence `jobboard.jac`.
5. **Regex flags:** `re.DOTALL` as a positional flag fails type-checking, so use an inline `(?s)`.
6. **HTTPS:** the bundled Python has no CA certs, so `slbfe.jac` builds an `ssl` context from certifi or the OS bundle.
7. **Narrowing in comprehensions:** "not None" narrowing is lost inside a comprehension, so copy the narrowed values into typed locals first.
8. **`sem` placement:** `sem` goes at top level (`sem Type.field = "...";`). Don't put double quotes inside a `sem` string.
9. **Client modules:** a module with no JSX is placed on the server, so pin pure client helpers as `.cl.jac` and mark their globals and defs `:pub` (0.34 exports nothing else). After renaming client modules, delete `.jac/client/compiled`.
10. **Nested walkers:** a walker spawned inside another walker sends its `report`s to the HTTP response. `Investigate(quiet=True)` suppresses that; read `inv.st.result` instead.

## Current status (17 Oct, ~12:55)

- **Working and verified on 0.34.24:** the live register lookup; the full agent team; the ask-the-person loop; the job board with its licence gate; impersonation-aware reviews; the community feed and alerts. Evals 8/8, API checks 11/11.
- **Backend hardening, done:**
  - **B1:** every LLM agent call has a fallback. Failures are logged as `Supervisor agent_failed` and the case still finishes using the deterministic rules. If the register is unreachable, lookups use the cached `Agency` nodes in the graph. Verified with all network dependencies down: impersonation was still caught.
  - **B2:** the supervisor cross-checks the Extractor with `rules.find_*`, adding missed phones and emails, correcting the licence number, and filling a missing visa type.
  - **B3:** salary realism. The investigator has a `salary_in_lkr` tool, and the deterministic `SALARY_BAIT` flag (+15) fires when an unskilled job pays more than about Rs. 450,000 a month.
  - **Licence expiry:** the register's `Valid upto` date is checked (`rules.licence_expiry_flag`). An expired licence scores +35; one expiring within 30 days scores +10.
  - **Duplicate-offer detector:** `Investigate.find_reposts` walks earlier `Offer` nodes. When the wording matches (word 3-gram similarity of at least 0.8, digits ignored) but the contact numbers differ, it flags `REPOST` (+20). Registered agency numbers are excluded, so genuine reposts don't trigger it.
  - Both are unit-tested in `rules.jac`, and the live server run passed `scripts/api_e2e.py` 11/11 with them loaded (17 Oct, 13:00).
- **Demo data:** `seed.jac` loads it through the API. Reset with `jac034 clean --data --force`, restart `jac034 start`, then `jac034 run seed.jac`. The video script is in `docs/DEMO_SCRIPT.md`. Ethics: board listings use a real licence, so they are genuine-looking, and their only negative report is an impersonation report, which leaves the agency's score untouched.
- **Not done:** Jac Hammer deploy (the user does it in the web UI: Jac version 0.34.24, env vars `OLLAMA_API_KEY`/`GEMINI_API_KEY`), demo video.
- **Restore point:** the git tag `jac-0.37-final` is the last version on jac 0.37.25.
