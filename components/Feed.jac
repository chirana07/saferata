"""Community checks (graph-wide), styled like the layout-coder design."""

import from agents { RecentChecks, CheckView }
import from .ui { LiveTag }

def verdict_cls(v: str) -> str {
    if v == "DANGER" {
        return "bg-risk-soft text-risk";
    }
    if v == "CAREFUL" {
        return "bg-caution-soft text-foreground";
    }
    return "bg-safe-soft text-safe";
}

def:pub CommunityFeed(refresh: int) -> JsxElement {
    has checks: list[CheckView] = [];

    async def load -> None {
        result = root spawn RecentChecks();
        checks = result.reports;
    }

    can with [refresh] entry {
        load();
    }

    return <section className="mt-12 border-t border-border pt-8">
        <div className="flex items-center justify-between"><h2 className="text-2xl font-bold">Community checks <span className="font-mono text-sm font-normal text-muted-foreground">{str(len(checks))}</span></h2><LiveTag label="Shared graph"/></div>
        <p className="mt-1 text-sm text-muted-foreground">Every check feeds one graph. When a phone number later turns up in a dangerous offer, the Network Guardian warns everyone who checked an offer with it.</p>
        <ul className="mt-4 divide-y divide-border rounded-xl border border-border bg-card">
            {if len(checks) == 0 { <li className="px-4 py-3 text-sm text-muted-foreground">No checks yet.</li> }}
            {[
                <li key={c.id} className="flex flex-wrap items-center gap-x-6 gap-y-1 px-4 py-3">
                    <span className="min-w-48 flex-1 font-semibold">{(c.job or "Job offer") + (" · " + c.country if c.country else "")}</span>
                    <span className="text-xs text-muted-foreground">{c.agency or "no agency named"}</span>
                    <span className="font-mono text-xs text-muted-foreground">{c.created_at}</span>
                    <span className={"rounded px-1.5 py-0.5 text-[11px] font-semibold " + verdict_cls(c.verdict)}>{f"{c.verdict} · {c.score}"}</span>
                    {[<span key={i} className="w-full text-xs font-semibold text-primary-deep">{"Alert: " + a}</span> for (i, a) in enumerate(c.alerts)]}
                </li>
                for c in checks
            ]}
        </ul>
    </section>;
}
