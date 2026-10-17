"""Shared UI primitives ported from the layout-coder design (same Tailwind classes), mapped to real backend data."""

import from "lucide-react" { ShieldCheck, ShieldAlert, ShieldQuestion, CircleDot, ArrowUpRight }

"""Backend band + score -> the design's four risk levels."""
def:pub risk_of(band: str, score: int) -> str {
    if band == "LOOKS SAFE" {
        return "low";
    }
    if band == "BE CAREFUL" {
        return "moderate";
    }
    if band == "DANGER" {
        return "critical" if score >= 85 else "high";
    }
    return "moderate";
}

def:pub risk_label(risk: str) -> str {
    if risk == "low" {
        return "Low risk";
    }
    if risk == "moderate" {
        return "Some concerns";
    }
    if risk == "high" {
        return "High risk";
    }
    return "Critical risk";
}

def:pub risk_text(risk: str) -> str {
    return "text-safe" if risk == "low" else ("text-foreground" if risk == "moderate" else "text-risk");
}

def:pub risk_bar(risk: str) -> str {
    return "bg-safe" if risk == "low" else ("bg-caution" if risk == "moderate" else "bg-risk");
}

def risk_n(risk: str) -> int {
    return 1 if risk == "low" else (2 if risk == "moderate" else (3 if risk == "high" else 4));
}

def:pub Logo -> JsxElement {
    return <span className="inline-flex items-center gap-2">
        <svg viewBox="0 0 28 28" className="h-7 w-7" aria-hidden="true">
            <rect width="28" height="28" rx="7" className="fill-primary"/>
            <path d="M5 19 Q14 6 23 19" className="fill-none stroke-primary-foreground" strokeWidth="2.4" strokeLinecap="round"/>
            <circle cx="23" cy="19" r="2.4" className="fill-sky"/>
            <path d="M5 22.5 H23" className="stroke-primary-foreground/50" strokeWidth="1.2"/>
        </svg>
        <span className="font-display text-lg font-bold tracking-tight">Safe<span className="text-primary">Rata</span></span>
    </span>;
}

def:pub SafetyIndicator(risk: str, compact: bool = False) -> JsxElement {
    n = risk_n(risk);
    return <div className="flex items-center gap-2">
        {if risk == "low" {
            <ShieldCheck className={"h-4 w-4 " + risk_text(risk)}/>
        } elif risk == "moderate" {
            <ShieldQuestion className={"h-4 w-4 " + risk_text(risk)}/>
        } else {
            <ShieldAlert className={"h-4 w-4 " + risk_text(risk)}/>
        }}
        {if not compact {
            <span className={"text-xs font-semibold " + risk_text(risk)}>{risk_label(risk)}</span>
        }}
        <span className="flex gap-0.5">
            {[<span key={i} className={"h-1.5 w-3 rounded-sm " + (risk_bar(risk) if i <= n else "bg-border")}></span> for i in [1, 2, 3, 4]]}
        </span>
    </div>;
}

def:pub MatchMeter(value: int) -> JsxElement {
    return <div className="flex items-center gap-2">
        <span className="font-mono text-xs font-semibold text-primary-deep">{f"{value}%"}</span>
        <span className="h-1 w-14 overflow-hidden rounded-sm bg-secondary">
            <span className="block h-full bg-primary" style={{"width": f"{value}%"}}></span>
        </span>
        <span className="text-xs text-muted-foreground">match</span>
    </div>;
}

def:pub VerifyBadge(state: str, prefix: str = "") -> JsxElement {
    cls = "bg-safe-soft text-safe" if state == "verified" else ("bg-caution-soft text-foreground" if state == "expired" else ("bg-risk-soft text-risk" if state == "rejected" else "bg-muted text-muted-foreground"));
    label = "Verified" if state == "verified" else ("Expired" if state == "expired" else ("Rejected" if state == "rejected" else "Unverified"));
    return <span className={"inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 text-[11px] font-semibold " + cls}>
        <CircleDot className="h-3 w-3"/>{(prefix + ": " if prefix else "") + label}
    </span>;
}

def:pub CountryTag(country: str) -> JsxElement {
    return <span className="inline-flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
        <span className="rounded-sm border border-border bg-card px-1 font-mono text-[10px] font-bold text-foreground">{country[:2].upper() if country else "--"}</span>{country}
    </span>;
}

"""One finding row. kind: confirmed | suspected | allegation | unavailable (design vocabulary)."""
def:pub FindingItem(title: str, risk: str, kind: str, source: str, excerpt: str, why: str, open_default: bool = False) -> JsxElement {
    has open: bool = False,
        touched: bool = False;
    is_open = open if touched else open_default;
    kcls = "bg-ink text-ink-foreground" if kind == "confirmed" else ("bg-caution-soft text-foreground" if kind == "suspected" else ("bg-secondary text-primary-deep" if kind == "allegation" else "bg-muted text-muted-foreground"));
    klabel = "Confirmed in text" if kind == "confirmed" else ("Suspected" if kind == "suspected" else ("Community evidence" if kind == "allegation" else "Data unavailable"));
    return <li className="border-b border-border last:border-0">
        <button onClick={lambda -> None { open = not is_open; touched = True; }} className="flex w-full items-start gap-3 py-3.5 text-left">
            <span className={"mt-1.5 h-2 w-2 shrink-0 rounded-sm " + risk_bar(risk)}></span>
            <span className="flex-1">
                <span className="block text-sm font-semibold">{title}</span>
                <span className="mt-1 flex flex-wrap gap-1.5">
                    <span className={"rounded px-1.5 py-0.5 text-[10px] font-semibold " + kcls}>{klabel}</span>
                    <span className="rounded border border-border px-1.5 py-0.5 text-[10px] text-muted-foreground">{source}</span>
                </span>
            </span>
            <ArrowUpRight className={"h-4 w-4 text-muted-foreground transition-transform " + ("rotate-90" if is_open else "")}/>
        </button>
        {if is_open {
            <div className="pb-4 pl-5 rise-in">
                {if excerpt {
                    <blockquote className="mb-2 border-l-2 border-risk bg-risk-soft/60 px-3 py-2 font-mono text-xs leading-relaxed">{"“" + excerpt + "”"}</blockquote>
                }}
                <p className="text-sm text-muted-foreground"><span className="font-semibold text-foreground">Why it matters: </span>{why}</p>
            </div>
        }}
    </li>;
}

def:pub LiveTag(label: str = "Live data") -> JsxElement {
    return <span className="inline-flex items-center gap-1.5 rounded-full border border-primary/30 bg-primary/5 px-2.5 py-0.5 font-mono text-[11px] font-semibold tracking-wide text-primary-deep">
        <span className="h-1.5 w-1.5 rounded-full bg-safe animate-pulse-live"></span>
        {label}
    </span>;
}

def:pub EmptyState(title: str, body: str) -> JsxElement {
    return <div className="rounded-xl border border-dashed border-border bg-card/60 px-6 py-12 text-center">
        <svg viewBox="0 0 120 40" className="mx-auto h-10 w-32" aria-hidden="true">
            <path d="M4 34 Q60 -6 116 34" className="fill-none stroke-sky" strokeWidth="2" strokeDasharray="4 5"/>
            <circle cx="116" cy="34" r="3" className="fill-primary"/>
        </svg>
        <h3 className="mt-4 text-lg font-semibold">{title}</h3>
        <p className="mx-auto mt-1 max-w-sm text-sm text-muted-foreground">{body}</p>
    </div>;
}

def:pub PageHeader(eyebrow: str, title: str, accent: str = "", children: any = None) -> JsxElement {
    return <header className="mb-8 flex flex-wrap items-end justify-between gap-4 border-b border-border pb-6">
        <div>
            <p className="eyebrow">{eyebrow}</p>
            <h1 className="mt-2 text-4xl font-bold leading-[0.95] tracking-tight md:text-5xl">{title}{if accent { <span className="text-primary">{" " + accent}</span> }}</h1>
        </div>
        {children}
    </header>;
}

def:pub CourtroomCard(role: str, speaker: str, argument: str) -> JsxElement {
    is_judge = "judge" in role.lower();
    is_prosecutor = "prosecut" in role.lower();
    header_cls = "bg-primary text-primary-foreground" if is_judge else ("bg-risk-soft text-risk border-b border-risk/20" if is_prosecutor else "bg-muted text-foreground border-b border-border");
    border_cls = "border-primary/40 shadow-card" if is_judge else "border-border";
    return <div className={"overflow-hidden rounded-xl border bg-card " + border_cls}>
        <div className={"flex items-center justify-between px-4 py-2.5 text-xs font-semibold " + header_cls}>
            <span className="uppercase tracking-wider">{role}</span>
            <span className="font-mono opacity-80">{speaker}</span>
        </div>
        <div className="p-4">
            <p className="text-sm leading-relaxed text-muted-foreground">{argument}</p>
        </div>
    </div>;
}

def:pub RiskGauge(score: int, band: str) -> JsxElement {
    s = max(0, min(100, score));
    offset = int(151.0 * (1.0 - (s / 100.0)));
    stroke_color = "#10b981" if s < 25 else ("#f59e0b" if s < 60 else "#ef4444");
    text_color = "text-safe" if s < 25 else ("text-foreground" if s < 60 else "text-risk");
    band_label = "LOOKS SAFE" if s < 25 else ("BE CAREFUL" if s < 60 else "CRITICAL DANGER");

    return <div className="flex flex-col items-center justify-center p-2 text-center">
        <div className="relative h-24 w-44">
            <svg viewBox="0 0 120 75" className="h-full w-full overflow-visible">
                <path d="M 12 62 A 48 48 0 0 1 108 62" fill="none" stroke={stroke_color} strokeWidth="12" strokeLinecap="round" opacity="0.18"/>
                <path d="M 12 62 A 48 48 0 0 1 108 62" fill="none" stroke="currentColor" strokeWidth="8" strokeLinecap="round" className="text-border/60"/>
                <path d="M 12 62 A 48 48 0 0 1 108 62" fill="none" stroke={stroke_color} strokeWidth="8.5" strokeLinecap="round"
                    strokeDasharray="151" strokeDashoffset={str(offset)}
                    style={{"transition": "stroke-dashoffset 1.2s cubic-bezier(0.16, 1, 0.3, 1)"}}/>
            </svg>
            <div className="absolute inset-x-0 bottom-1 flex flex-col items-center justify-center">
                <span className="font-display text-3xl font-extrabold tracking-tight">{f"{s}"}</span>
                <span className="font-mono text-[10px] uppercase tracking-wider opacity-75">Score / 100</span>
            </div>
        </div>
        <div className="mt-1 flex items-center gap-1.5">
            <span className={"h-2 w-2 rounded-full animate-pulse " + ("bg-safe" if s < 25 else ("bg-caution" if s < 60 else "bg-risk"))}></span>
            <span className={"font-mono text-xs font-bold uppercase tracking-wide " + text_color}>{band_label}</span>
        </div>
    </div>;
}
