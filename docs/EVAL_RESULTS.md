# Evaluation results (17 Oct 2026, live models + live SLBFE register)

Run: `jac run --no-takeover evals.jac`

```
PASS | Thailand IT job (trafficking)    | got DANGER     100/100 | expected DANGER
PASS | Licensed agency impersonated     | got BE CAREFUL  55/100 | expected DANGER or BE CAREFUL
PASS | Genuine licensed offer           | got LOOKS SAFE   0/100 | expected LOOKS SAFE
PASS | Fake licence number              | got DANGER      65/100 | expected DANGER
PASS | Dubai housemaid on visit visa    | got DANGER     100/100 | expected DANGER or BE CAREFUL
PASS | Russia security job              | got DANGER      90/100 | expected DANGER or BE CAREFUL
6/6 verdicts correct
```

Regression cases added after the 11:30 logic review (wrong licence number on a real agency name; agency name written differently) were verified via the API and are now in evals.jac.
