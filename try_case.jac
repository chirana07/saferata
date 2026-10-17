"""Dev helper: run one sample offer through the agent team from the command line."""
import sys;
import json;
import from agents { Investigate, CaseReport }

with entry:__main__ {
    path = sys.argv[-1];
    text = open(path).read();
    res = root spawn Investigate(text=text, answers=["Yes, they want the money before any contract."]);
    for r in res.reports {
        for s in r.steps { print(f"[{s.agent}] {s.action}: {s.detail}"); }
        print("STATUS", r.status, r.band, r.score, r.register_status);
        for f in r.flags { print(" FLAG", f.points, f.source, "|", f.title, "|", f.evidence); }
        print("REMOVED", r.removed);
    }
}
