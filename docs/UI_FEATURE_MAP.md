# UI design (layout-coder) vs the SafeRata backend

Source design: github.com/Denuwan392/layout-coder, a Lovable React prototype built 17 Oct 12:13–12:35. Every piece of its data and agent logic is marked "SIMULATED". We rebuild its screens in **Jac**, because copying the TSX would break the 80% Jac rule, and connect them to the real backend.

**Legend:**
- ✅ the backend has it
- 🟡 partly (or derivable, or done client-side)
- ❌ not built in the backend; shown as "not available" or left out

## Screen by screen

| Screen | Design feature | Backend | Notes |
|---|---|---|---|
| **Check an offer** | Paste offer → agent activity → verdict | ✅ | `Investigate` walker (real agents, live SLBFE register) |
| | Risk level + score | ✅ | Bands Looks safe / Be careful / Danger with transparent points |
| | Confidence % | 🟡 | Derived from the facts found and the register status (computed, not an LLM output) |
| | Findings with exact quotes + source | ✅ | `RedFlag` evidence + trust level; the critic enforces quotes |
| | Extracted evidence (salary, visa, fee, licence, employer) | ✅ | `OfferFacts` + the supervisor's pattern cross-check |
| | Missing information / follow-up questions | ✅ | `ask_user` pause-and-ask loop |
| | Ask before paying / next steps / draft report | ✅ | Advisor agent |
| **Discover** | Job list with safety badge, search, filters | ✅ / 🟡 | `ListJobs`; search and filters run client-side over the list |
| | Salary in LKR | ✅ | `to_lkr` (approximate fixed rates) |
| | Match % from the worker's profile | ❌ | **No profile or matching backend.** Left out. |
| | Featured / promoted listings | ❌ | Not built (and the design itself says promotion must not affect safety) |
| | Saved jobs | ❌ | Not built |
| **Job detail** | Salary, safety findings, visa/contract, who's behind it | ✅ | `JobView` + the agency from the register |
| | Pay & deductions, estimated take-home, accommodation, contract type, experience | ❌ | `PostJob` doesn't collect these fields |
| | "Why it matches" | ❌ | Needs profile matching |
| | Enquire / questions to copy | 🟡 | Static checklist (same as the Advisor's defaults) |
| **Companies** | List with licence, listings, reports | ✅ | New `ListAgencies` walker over `Agency` nodes |
| **Company detail** | Licence state + last checked | ✅ | Live register record cached in the graph (`checked_at`) |
| | Listings + worker reports | ✅ | Jobs linked to the agency + `Review` nodes (Review Verifier: credible / unverified, impersonation) |
| | Related entities | 🟡 | Derivable from shared `Contact` nodes; not shown yet |
| | Agency response, request correction | ❌ | Not built |
| | Submit a report | ✅ | `AddReview` on one of the agency's jobs |
| **Agency portal** | New listing → verification | ✅ | `PostJob`: live licence gate + full agent analysis |
| | Pre-publication checklist | 🟡 | Computed in the UI from the form fields |
| | Document upload (demand letter, contract) | ❌ | Not built |
| | Dispute / appeal a finding | ❌ | Not built |
| **Profile** | Worker profile (skills, destinations, minimum salary) | ❌ | **No backend.** Screen not rebuilt. |
| **Compare** | Side-by-side jobs | ❌ | Not built |

## Backend features with no screen in the design

The rebuilt UI must surface these, because they are what makes the agents real:
- **Live SLBFE register verification** with registered phone numbers (impersonation detection)
- **Prosecutor / Defender / Judge debate,** the critic's removals, and the score breakdown
- **Community graph:** checks by everyone, the Network Guardian alerts, and the duplicate-ad (`REPOST`) detector
- **Impersonation-aware reviews** (a scam number is flagged without lowering the genuine agency's score)
- **Graceful degradation** (`agent_failed` steps)
