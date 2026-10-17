"""SafeRata client shell: top navigation + screens (layout from the layout-coder design, real Jac backend)."""

import from .components.Check { CheckOffer }
import from .components.Discover { Discover }
import from .components.Agency { AgencyPortal }
import from .components.Companies { Companies }
import from .components.Profile { Profile }
import from .components.Feed { CommunityFeed }
import from .components.theme { BG, INK, MUTED_INK, PRIMARY, PRIMARY_DEEP, BORDER }

glob TABS: list[list[str]] = [["discover", "Discover"], ["check", "Check an offer"], ["companies", "Companies"], ["agency", "Agency portal"], ["profile", "Profile"]];

def:pub app -> JsxElement {
    has tab: str = "check",
        refresh: int = 0;

    def bump {
        refresh = refresh + 1;
    }

    return <div style={{"minHeight": "100vh", "background": BG, "color": INK, "fontFamily": "Inter, system-ui, -apple-system, Segoe UI, sans-serif"}}>
        <header style={{"background": "#ffffff", "borderBottom": "1px solid " + BORDER, "position": "sticky", "top": "0", "zIndex": "5"}}>
            <div style={{"maxWidth": "1180px", "margin": "0 auto", "padding": "12px 20px", "display": "flex", "alignItems": "center", "gap": "24px", "flexWrap": "wrap"}}>
                <div style={{"display": "flex", "alignItems": "center", "gap": "8px"}}>
                    <span style={{"width": "28px", "height": "28px", "borderRadius": "8px", "background": PRIMARY, "color": "white", "display": "flex", "alignItems": "center", "justifyContent": "center", "fontWeight": "800"}}>S</span>
                    <span style={{"fontWeight": "800", "fontSize": "18px", "letterSpacing": "-0.3px"}}>SafeRata</span>
                </div>
                <nav style={{"display": "flex", "gap": "4px", "flexWrap": "wrap"}}>
                    {[
                        <button key={t[0]} onClick={lambda -> None { tab = t[0]; }}
                            style={{"background": "#e1e8fb" if tab == t[0] else "transparent", "color": PRIMARY_DEEP if tab == t[0] else MUTED_INK, "border": "none", "borderRadius": "8px", "padding": "8px 12px", "fontWeight": "600", "fontSize": "14px", "cursor": "pointer"}}>{t[1]}</button>
                        for t in TABS
                    ]}
                </nav>
                <span style={{"marginLeft": "auto", "fontSize": "12px", "color": MUTED_INK}}>Live SLBFE register · 10 AI agents · Jac 0.34</span>
            </div>
        </header>
        <main style={{"maxWidth": "1180px", "margin": "0 auto", "padding": "24px 20px 48px"}}>
            {if tab == "check" {
                <div>
                    <h1 style={{"fontSize": "32px", "margin": "0 0 4px", "letterSpacing": "-0.5px"}}>Check an offer <span style={{"color": PRIMARY}}>before you pay.</span></h1>
                    <p style={{"color": MUTED_INK, "margin": "0 0 20px"}}>A team of AI agents investigates it against the official SLBFE licensed-agency register.</p>
                    <CheckOffer onChecked={bump}/>
                    <CommunityFeed refresh={refresh}/>
                </div>
            }}
            {if tab == "discover" {
                <Discover onCheck={lambda -> None { tab = "check"; }} onProfile={lambda -> None { tab = "profile"; }}/>
            }}
            {if tab == "agency" {
                <AgencyPortal onPosted={bump}/>
            }}
            {if tab == "profile" {
                <Profile/>
            }}
            {if tab == "companies" {
                <Companies refresh={refresh}/>
            }}
        </main>
    </div>;
}
