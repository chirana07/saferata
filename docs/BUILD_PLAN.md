# Build plan: one part at a time

Rule: build one part, run its check, commit, then start the next. Do not start a part while the previous part's check is failing.

## Done (each one verified)

| # | Part | Files | Check that proves it works | Status |
|---|---|---|---|---|
| 1 | Live SLBFE register lookup | `slbfe.jac` | Licence 3500 returns ATC Global with 3 phones and its expiry date; name search works; licence 9998 returns nothing | ✅ |
| 2 | Rules, critic, scorer | `rules.jac` | `jac test rules.jac` passes (3 tests) | ✅ |
| 3 | Agent investigation | `agents.jac`, `graph.jac`, `models.jac` | `jac test agents.jac` (name matching); `evals.jac` gets every labelled offer right | ✅ (re-verifying after the logic fixes) |
| 4 | Check-an-offer UI | `frontend.jac`, `frontend.impl.jac` | In the browser, all 4 samples give a verdict; the vague sample asks a question and continues | ✅ |
| 5 | Job board backend | `board.jac` | API: posting checks the licence live and runs the analysis; a fraud review is verified and re-scores the job; one report per response | ✅ |
| 6 | Community feed | `components/Feed.jac` | Recent checks are listed after each investigation | ✅ |

## Logic fixes from the 11:30 review (part of part 3)

- Agency names now match across spacing and suffixes ("ATC Global Holdings" = "A T C GLOBAL HOLDINGS (PVT) LTD"). Before, this gave a false +35.
- A printed licence number that doesn't exist, or belongs to another agency, is flagged even when the agency name is real.
- The impersonation check runs only against a verified agency.
- Community reports ignore earlier checks of the same text, so re-checking an offer doesn't penalise it.
- An agency's registered phone numbers are never linked into the scam graph.
- A posted job's nested investigation no longer adds a second report to the response.
- Fraud-review alerts fire once, when a job first becomes Danger.

## Next, in order

| # | Part | Check | Owner |
|---|---|---|---|
| 7 | Job board UI end to end | In the browser: post the sample job, see the badge, add a fraud review, see the re-score and the alert in the community feed | Claude |
| 8 | Clean database + demo seed | `seed.jac` resets the data and loads a realistic history (2 jobs, 4 checks), so the demo shows community links | Claude |
| 9 | Jac Hammer deploy | The hosted preview runs the Thailand sample; the register shows NOT_FOUND, not UNREACHABLE | You (web UI), Claude fixes errors |
| 10 | Screenshot input (stretch) | Upload a screenshot of an ad; the Reader agent transcribes it; the verdict matches the text version | Claude |
| 11 | Sinhala output (stretch) | A toggle gives the advice and explanations in Sinhala | Claude |
| 12 | Video + submission | 3-minute video, description, links | Team |

**Feature freeze at 15:45.** Parts 10 and 11 are cut if part 9 isn't done by 14:30.
