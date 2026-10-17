# Evaluation results (17 Oct 2026, jac 0.34.24, live models + live SLBFE register)

Run: `jac run evals.jac`

```
PASS | Thailand IT job (trafficking)    | got DANGER     100/100 | expected DANGER
PASS | Licensed agency impersonated     | got BE CAREFUL  55/100 | expected DANGER or BE CAREFUL
PASS | Genuine licensed offer           | got LOOKS SAFE   0/100 | expected LOOKS SAFE
PASS | Fake licence number              | got DANGER      83/100 | expected DANGER
PASS | Dubai housemaid on visit visa    | got DANGER     100/100 | expected DANGER or BE CAREFUL
PASS | Real agency name, wrong licence no. | got BE CAREFUL  45/100 | expected DANGER or BE CAREFUL
PASS | Genuine, name written differently | got LOOKS SAFE   0/100 | expected LOOKS SAFE
PASS | Russia security job              | got DANGER      90/100 | expected DANGER or BE CAREFUL
8/8 verdicts correct
```

Backend API checks (`python3 scripts/api_e2e.py` against `jac start`): 11/11 passed on jac 0.34.24.
