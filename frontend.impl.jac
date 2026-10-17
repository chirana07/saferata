"""Implementations for the SafeRata frontend component."""

impl app.investigate -> None {
    if not text.strip() {
        error = "Paste an offer first.";
        return;
    }
    error = "";
    busy = True;
    outcome = None;
    answers = [];
    result = root spawn Investigate(text=text);
    if result.reports {
        outcome = result.reports[0];
    } else {
        error = "The agents could not finish. Please try again.";
    }
    busy = False;
}

impl app.submit_answers -> None {
    if outcome is None {
        return;
    }
    qs = outcome.questions;
    pairs = [f"Q: {q} A: {answers[i] if i < len(answers) else 'unknown'}" for (i, q) in enumerate(qs)];
    busy = True;
    result = root spawn Investigate(text=text, answers=pairs);
    if result.reports {
        outcome = result.reports[0];
    } else {
        error = "The agents could not finish. Please try again.";
    }
    busy = False;
}
