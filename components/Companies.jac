"""Companies: agencies verified on the live SLBFE register, with their listings and moderated worker reports."""

import from jobboard { ListAgencies, AgencyView, JobView }
import from .theme { INK, MUTED_INK, PRIMARY, PRIMARY_DEEP, ACCENT, MUTED, BORDER, RISK, RISK_SOFT, CARD, LABEL, band_label, band_fg, band_bg }
import from .Discover { NotBuilt }

def:pub Companies(refresh: int) -> JsxElement {
    has agencies: list[AgencyView] = [],
        open_id: str = "";

    async def load -> None {
        result = root spawn ListAgencies();
        agencies = result.reports;
    }

    can with [refresh] entry {
        load();
    }

    opened = [a for a in agencies if a.id == open_id];
    th = {"textAlign": "left", "fontSize": "12px", "color": MUTED_INK, "padding": "8px", "borderBottom": "1px solid " + BORDER};
    td = {"padding": "10px 8px", "borderBottom": "1px solid " + MUTED, "fontSize": "14px"};

    if opened {
        ag = opened[0];
        return <div style={{"display": "flex", "flexDirection": "column", "gap": "16px"}}>
            <button onClick={lambda -> None { open_id = ""; }} style={{"alignSelf": "flex-start", "background": "transparent", "border": "none", "color": PRIMARY, "fontWeight": "600", "cursor": "pointer", "padding": "0"}}>{"← All companies"}</button>
            <div style={CARD}>
                <h2 style={{"margin": "0"}}>{ag.name}</h2>
                <div style={{"color": MUTED_INK, "marginTop": "4px"}}>Recruitment agency</div>
                <div style={{"display": "grid", "gridTemplateColumns": "repeat(4, minmax(0, 1fr))", "gap": "12px", "marginTop": "14px"}}>
                    <div><div style={LABEL}>Licence</div><div style={{"fontWeight": "700"}}>{ag.licence_no}</div><div style={{"fontSize": "12px", "color": "#1d8a55"}}>Verified on the live SLBFE register</div></div>
                    <div><div style={LABEL}>Valid until</div><div style={{"fontWeight": "700"}}>{ag.valid_upto}</div></div>
                    <div><div style={LABEL}>Last checked</div><div style={{"fontWeight": "700"}}>{ag.checked_at or "n/a"}</div></div>
                    <div><div style={LABEL}>Registered contacts</div><div style={{"fontSize": "13px"}}>{", ".join(ag.phones + ([ag.email] if ag.email else []))}</div></div>
                </div>
            </div>
            {[<div key={i} style={{"background": "#f5eef8", "border": "1px solid #c4a7e7", "borderRadius": "12px", "padding": "12px", "color": "#4c1d95", "fontWeight": "600"}}>{"Impersonation alert: " + w}</div> for (i, w) in enumerate(ag.warnings)]}
            <div style={{"display": "grid", "gridTemplateColumns": "minmax(0, 7fr) minmax(0, 5fr)", "gap": "16px", "alignItems": "start"}}>
                <div style={CARD}>
                    <div style={LABEL}>{f"Listings ({len(ag.jobs)})"}</div>
                    {[
                        <div key={j.id} style={{"padding": "10px 0", "borderBottom": "1px solid " + MUTED}}>
                            <div style={{"display": "flex", "justifyContent": "space-between", "gap": "8px"}}>
                                <b>{j.title + " · " + j.country}</b>
                                <span style={{"background": band_bg(j.band), "color": band_fg(j.band), "borderRadius": "999px", "padding": "2px 9px", "fontSize": "12px", "fontWeight": "700"}}>{f"{band_label(j.band)} {j.score}"}</span>
                            </div>
                            {[<div key={k} style={{"fontSize": "13px", "marginTop": "4px"}}>{f"{rv.author} ({rv.kind}, {rv.status}): {rv.text[:160]}"}</div> for (k, rv) in enumerate(j.reviews)]}
                        </div>
                        for j in ag.jobs
                    ]}
                </div>
                <div style={{"display": "flex", "flexDirection": "column", "gap": "16px"}}>
                    <div style={CARD}>
                        <div style={LABEL}>Moderated worker reports</div>
                        <div style={{"fontSize": "28px", "fontWeight": "800", "marginTop": "6px"}}>{str(ag.reports)}</div>
                        <div style={{"color": RISK if ag.credible_fraud > 0 else MUTED_INK, "fontWeight": "600"}}>{f"{ag.credible_fraud} credible fraud report(s) against the agency itself"}</div>
                        <div style={{"fontSize": "12px", "color": MUTED_INK, "marginTop": "6px"}}>Reports about impersonators do not lower the agency's own score.</div>
                    </div>
                    <div style={CARD}>
                        <div style={LABEL}>Not in the backend yet</div>
                        <div style={{"display": "flex", "gap": "6px", "flexWrap": "wrap", "marginTop": "8px"}}>
                            <NotBuilt label="Agency response"/><NotBuilt label="Request correction"/><NotBuilt label="Related entities"/>
                        </div>
                    </div>
                </div>
            </div>
        </div>;
    }

    return <div style={{"display": "flex", "flexDirection": "column", "gap": "14px"}}>
        <div>
            <h1 style={{"fontSize": "32px", "margin": "0 0 4px"}}>{"Know who you're "}<span style={{"color": PRIMARY}}>dealing with.</span></h1>
            <p style={{"color": MUTED_INK, "margin": "0"}}>Agencies the system has verified on the live SLBFE register, with their listings and worker reports.</p>
        </div>
        <div style={CARD}>
            {if len(agencies) == 0 {
                <p style={{"color": MUTED_INK, "margin": "0"}}>No agencies verified yet. They appear here after a check or a job posting finds them on the register.</p>
            } else {
                <table style={{"width": "100%", "borderCollapse": "collapse"}}>
                    <thead><tr><th style={th}>Name</th><th style={th}>Type</th><th style={th}>Licence</th><th style={th}>Valid until</th><th style={th}>Listings</th><th style={th}>Reports</th><th style={th}></th></tr></thead>
                    <tbody>
                        {[
                            <tr key={a.id}>
                                <td style={td}><b>{a.name}</b></td>
                                <td style={td}>Recruitment agency</td>
                                <td style={td}>{a.licence_no}</td>
                                <td style={td}>{a.valid_upto}</td>
                                <td style={td}>{str(len(a.jobs))}</td>
                                <td style={td}>{str(a.reports) + (f" ({a.credible_fraud} fraud)" if a.credible_fraud else "")}</td>
                                <td style={td}><button onClick={lambda -> None { open_id = a.id; }} style={{"background": ACCENT, "color": PRIMARY_DEEP, "border": "none", "borderRadius": "8px", "padding": "5px 10px", "fontWeight": "600", "cursor": "pointer"}}>Open</button></td>
                            </tr>
                            for a in agencies
                        ]}
                    </tbody>
                </table>
            }}
        </div>
    </div>;
}
