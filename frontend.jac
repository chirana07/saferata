"""SafeRata client shell: the layout-coder AppShell (sidebar nav) ported to Jac, with the real-backend screens."""

import from "lucide-react" { Compass, Radar, Building2, UserRound, Briefcase }
import from .components.Check { CheckOffer }
import from .components.Discover { Discover }
import from .components.Agency { AgencyPortal }
import from .components.Companies { Companies }
import from .components.Profile { Profile }
import from .components.Feed { CommunityFeed }
import from .components.ui { Logo }

def:pub NavItem(label: str, active: bool, kind: str, onGo: Callable[[], None]) -> JsxElement {
    def go(e: MouseEvent) {
        onGo();
    }
    return <button onClick={go} className={"flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-left text-sm font-medium transition-all " + ("bg-primary text-primary-foreground shadow-sm" if active else "text-muted-foreground hover:bg-sidebar-accent hover:text-foreground")}>
        {if kind == "discover" { <Compass className="h-4 w-4 shrink-0"/> } elif kind == "check" { <Radar className="h-4 w-4 shrink-0"/> } elif kind == "companies" { <Building2 className="h-4 w-4 shrink-0"/> } else { <UserRound className="h-4 w-4 shrink-0"/> }}
        <span className="truncate">{label}</span>
    </button>;
}

def:pub app -> JsxElement {
    has tab: str = "discover",
        refresh: int = 0;

    def bump {
        refresh = refresh + 1;
    }

    return <div className="min-h-screen md:grid md:grid-cols-[240px_1fr]">
        <aside className="sticky top-0 hidden h-screen flex-col border-r border-border bg-sidebar px-4 py-6 md:flex">
            <button onClick={lambda -> None { tab = "discover"; }} className="px-2 text-left"><Logo/></button>
            <nav className="mt-8 flex flex-col gap-1">
                <NavItem label="Discover" kind="discover" active={tab == "discover"} onGo={lambda -> None { tab = "discover"; }}/>
                <NavItem label="Investigate" kind="check" active={tab == "check"} onGo={lambda -> None { tab = "check"; }}/>
                <NavItem label="Companies" kind="companies" active={tab == "companies"} onGo={lambda -> None { tab = "companies"; }}/>
                <NavItem label="Profile" kind="profile" active={tab == "profile"} onGo={lambda -> None { tab = "profile"; }}/>
            </nav>
            <div className="mt-6 border-t border-border pt-4">
                <p className="eyebrow px-3 text-[10px]">Agencies & Employers</p>
                <button onClick={lambda -> None { tab = "agency"; }} className={"mt-2 flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-left text-sm font-medium transition-all " + ("bg-ink text-ink-foreground shadow-sm" if tab == "agency" else "text-muted-foreground hover:bg-sidebar-accent hover:text-foreground")}>
                    <Briefcase className="h-4 w-4 shrink-0"/> Agency Portal
                </button>
            </div>
            <div className="mt-auto rounded-xl border border-border bg-card p-3.5 shadow-sm">
                <div className="flex items-center gap-2">
                    <span className="relative flex h-2 w-2">
                        <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-safe opacity-75"></span>
                        <span className="relative inline-flex h-2 w-2 rounded-full bg-safe"></span>
                    </span>
                    <span className="font-mono text-[11px] font-bold text-foreground">SLBFE Register Live</span>
                </div>
                <p className="mt-1.5 text-[11px] leading-relaxed text-muted-foreground">Agencies and licences verified against live government records.</p>
            </div>
        </aside>
        <div className="min-w-0">
            <header className="sticky top-0 z-20 flex items-center justify-between border-b border-border bg-card/90 px-4 py-3 backdrop-blur md:hidden">
                <Logo/>
                <button onClick={lambda -> None { tab = "agency"; }} className="rounded-md border border-border bg-card px-2.5 py-1 text-xs font-semibold text-primary">Agency portal</button>
            </header>
            <main className="mx-auto max-w-[1240px] px-4 pb-28 pt-6 md:px-10 md:pb-16 md:pt-10">
                {if tab == "discover" {
                    <Discover onCheck={lambda -> None { tab = "check"; }} onProfile={lambda -> None { tab = "profile"; }}/>
                }}
                {if tab == "check" {
                    <div>
                        <CheckOffer onChecked={bump}/>
                        <CommunityFeed refresh={refresh}/>
                    </div>
                }}
                {if tab == "companies" {
                    <Companies refresh={refresh}/>
                }}
                {if tab == "agency" {
                    <AgencyPortal onPosted={bump}/>
                }}
                {if tab == "profile" {
                    <Profile/>
                }}
            </main>
        </div>
        <nav className="fixed inset-x-0 bottom-0 z-30 grid grid-cols-4 border-t border-border bg-card/95 backdrop-blur md:hidden">
            {[<button key={t[0]} onClick={lambda -> None { tab = t[0]; }} className={"flex min-h-14 flex-col items-center justify-center gap-1 text-[11px] font-semibold transition-colors " + ("text-primary" if tab == t[0] else "text-muted-foreground hover:text-foreground")}>{t[1]}</button> for t in [["discover", "Discover"], ["check", "Investigate"], ["companies", "Companies"], ["profile", "Profile"]]]}
        </nav>
    </div>;
}
