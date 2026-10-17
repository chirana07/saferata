# Next steps (handoff checkpoint, 17 Oct 2026 ~13:40)

Read `AGENTS.md` first: toolchain (jac 0.34.24 at `~/.local/bin/jac034`), secrets, commands, design rules, 0.34 pitfalls. This file lists only what's left.

## State at this checkpoint

- **Backend:** complete and verified on jac 0.34.24.
  - API checks 11/11 (`python3 scripts/api_e2e.py`)
  - Evals 8/8 (`jac034 run evals.jac`)
  - Unit tests pass (`jac034 test rules.jac`, `jac034 test agents.jac`)
- **UI:** an exact port of the layout-coder design (Tailwind v4 + lucide, written in Jac). Screens: Discover, job detail, Investigate, Companies + company page, Agency portal, Profile.
- **Repo:** https://github.com/chirana07/saferata (main). Restore tag for the old 0.37 version: `jac-0.37-final`.
- **Demo data:** seeded cleanly at handoff (3 listings, 5 checks, 1 impersonation report, 1 positive review; the date fix is confirmed, since the positive review is now credible). To redo it:
  ```bash
  pkill -f "jac034 start"; pgrep -fl "jac034 start"   # must print nothing
  jac034 clean --data --force
  jac034 start --port 8000 &                          # with OLLAMA_API_KEY / GEMINI_API_KEY loaded
  jac034 run seed.jac                                 # ~4 minutes
  ```

## To do, in priority order

1. **Spot-check the UI** (5 minutes): click through every screen at http://localhost:8000. The data is already seeded.
2. **Deploy on Jac Hammer** (the web UI only; the jachammer CLI is broken):
   - jachammer.ai → New project → From GitHub → `chirana07/saferata`
   - Settings → Jac version **0.34.24**
   - Environment variables: `OLLAMA_API_KEY`, `GEMINI_API_KEY`
   - Check the preview: run the Thailand sample in Investigate. The register line must read `NOT_FOUND`, not `UNREACHABLE`; `UNREACHABLE` means the host can't reach applications.slbfe.lk. The code falls back to cached register entries, but seed locally first.
   - Publish, and put the public link in `README.md`.
3. **Record the demo video** (max 3 minutes) following `docs/DEMO_SCRIPT.md`. Upload to YouTube as unlisted.
4. **Submit (window 17:15–17:30):**
   - the GitHub link
   - the video link
   - the Jac Hammer link
   - a written description: adapt "How we used Jac and Jaseci" from `README.md` / the team doc
   - the jaseci-labs/jac repo is already starred
5. **Optional, only if there's time:**
   - Run the accepted-appeal path live once: post a listing via the Agency portal "Fill sample", then dispute an agent finding.
   - Rerun `python3 scripts/api_e2e.py` against the deployed URL: `SAFERATA_URL` for seed; edit `BASE` in the script.

## Not built (flagged in the UI with "not built yet")

- **Document upload and analysis** for the agency portal (only file names are kept).
- **Saved jobs and Compare** (from the design).
- **Agency identity verification.** Anyone with a licence number can post or respond as an agency; next step is a one-time code sent to the agency's registered phone.

## Known limitations (state these honestly in the video and README)

- **Expired licences:** the SLBFE register lists only valid agencies, so "not found" can't tell an expired licence from a fake one.
- **Approximate figures:** LKR conversions use fixed approximate rates, and the salary-bait threshold (~Rs. 450,000 for unskilled jobs) is a heuristic.
- **Model variance:** LLM verdict scores vary a little between runs; bands are stable on the eval set.
- **Language:** English only.
