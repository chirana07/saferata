# Demo video script (3 minutes)

**Before recording:** run `jac clean --data --force`, then `jac start`, then `jac run seed.jac` (about 4 minutes). The seed loads:
- 3 genuine listings under a real SLBFE licence
- 5 community checks (Thailand IT scam, Dubai visit-visa housemaid, fake licence 9998, Russia "security" job, ATC impersonation ad)
- 1 impersonation report and 1 positive review

## 1. Hook (15 s)
Many thousands of Sri Lankans pay recruiters for jobs abroad every year. Some arrive on a tourist visa with no job; some end up in scam compounds. SafeRata checks the offer **before** you pay.

## 2. Investigate: the reposted Thailand ad (45 s)
Paste this. It's the seeded Thailand ad, reposted with a new number and a higher salary:

```
URGENT HIRING!!! IT / Data Entry jobs in THAILAND
Salary USD 1800 per month + free accommodation + food
No experience needed, basic English and typing only.
Air ticket FREE. Travel on tourist visa, company will change to work visa after arrival.
Only 5 seats left - pay Rs. 150,000 processing fee to confirm your seat.
Deposit to Commercial Bank account 8012345678 (K. Perera). Send slip on WhatsApp +94 77 888 4411
```

Point out:
- the agent activity panel as it runs
- **Danger**
- the findings, each quoting the ad: tourist visa, personal account, fee before contract, salary bait (USD 1,800 is about Rs. 540,000 for an unskilled job)
- **Duplicate detector:** same wording as an earlier checked offer, but a different number
- the Courtroom (prosecutor vs defender)
- the draft report to the SLBFE 1989 hotline

## 3. Impersonation of a real licensed agency (35 s)
Paste the "Agency impersonation" sample, then point out:
- the **live SLBFE register** confirms licence 3500 is real
- the WhatsApp number is **not** one of the agency's registered numbers, so the offer is flagged as impersonation
- the community check shows the number was already reported

## 4. The agents ask the person (20 s)
Click "Vague WhatsApp message". The investigator pauses: *"What visa did they say you will travel on?"* Answer "visit visa first", and the verdict follows.

## 5. Verified job board (35 s)
1. **Discover:** listings are only from agencies verified on the live register, each with a safety badge. Open "Light vehicle driver · Qatar" and show the **impersonation alert** that came from a worker report. The agency's own score stays clean, because the scammer was pretending.
2. **Agency portal:** submit licence `9998` and show that the Gatekeeper rejects it live.
3. **Companies:** the agency's register data, its listings and its reports.

## 6. How Jac powers it (30 s)
- **Walkers are the API.** The Lead Investigator is a `by llm` ReAct agent whose tools are walker methods.
- **Typed `by llm` agents** use `sem` for every field.
- **A persistent graph** links `Offer`, `Contact`, `Agency`, `Job`, `Review` and `Alert`, so community intelligence and alerts are graph walks.
- **Deterministic rules decide the points,** so the LLM can't invent a verdict.
- **Graceful degradation:** cases still finish if a model fails.
- **Results:** 8/8 labelled offers correct; 11/11 API checks.
