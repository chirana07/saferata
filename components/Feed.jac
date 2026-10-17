"""Community feed: recent checks by everyone, with Network Guardian alerts."""

import from agents { RecentChecks, CheckView }

def verdict_color(v: str) -> str {
    if v == "DANGER" {
        return "#c0392b";
    }
    if v == "CAREFUL" {
        return "#d68910";
    }
    return "#1e8449";
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

    return <div style={{"marginTop": "28px"}}>
        <h2 style={{"marginBottom": "6px"}}>Community checks</h2>
        <p style={{"color": "#566573", "marginTop": "0", "fontSize": "14px"}}>Every check feeds a shared graph. When a phone number later turns up in a dangerous offer, the Network Guardian warns everyone who checked an offer with it.</p>
        {if len(checks) == 0 {
            <p style={{"color": "#566573"}}>No checks yet.</p>
        }}
        {[
            <div key={c.id} style={{"display": "flex", "justifyContent": "space-between", "gap": "8px", "padding": "8px 10px", "borderBottom": "1px solid #eaeded", "flexWrap": "wrap"}}>
                <div>
                    <b>{(c.job or "Job offer") + (" - " + c.country if c.country else "")}</b>
                    <span style={{"color": "#566573", "fontSize": "13px"}}>{"  " + (c.agency or "no agency named") + " | " + c.created_at}</span>
                    {[<div key={i} style={{"color": "#6c3483", "fontSize": "13px", "marginTop": "4px"}}>{"Alert: " + a}</div> for (i, a) in enumerate(c.alerts)]}
                </div>
                <span style={{"background": verdict_color(c.verdict), "color": "white", "borderRadius": "999px", "padding": "2px 10px", "fontSize": "12px", "fontWeight": "700", "height": "fit-content"}}>{f"{c.verdict} {c.score}"}</span>
            </div>
            for c in checks
        ]}
    </div>;
}
