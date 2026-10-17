"""Agent Orchestration Web: Interactive visual map of SafeRata's multi-agent architecture and Jaseci graph."""

import from "lucide-react" {
    Network, Workflow, Cpu, Layers, ShieldCheck, ShieldAlert,
    Scale, Search, Database, ArrowRight, Play, CheckCircle2,
    AlertTriangle, Bot, FileText, PhoneCall, Sparkles, HelpCircle
}

def ScenarioButton(id: str, title: str, badge: str, desc: str, is_active: bool, onPick: Callable[[str], None]) -> JsxElement {
    badge_style = "bg-risk/10 text-risk" if "DANGER" in badge else ("bg-safe/10 text-safe" if "SAFE" in badge else "bg-caution/10 text-caution");
    card_style = "border-primary bg-primary/5 ring-1 ring-primary shadow-sm" if is_active else "border-border bg-card/60 hover:border-border-accent hover:bg-card";

    return <button onClick={lambda { onPick(id); }} className={"rounded-lg border p-3.5 text-left transition-all " + card_style}>
        <div className="flex items-center justify-between gap-2 mb-1">
            <span className="text-xs font-bold text-foreground">{title}</span>
        </div>
        <span className={"inline-block text-[11px] font-mono font-bold px-1.5 py-0.5 rounded " + badge_style}>{badge}</span>
        <p className="text-[11px] text-muted-foreground mt-2 line-clamp-2 leading-relaxed">{desc}</p>
    </button>;
}

def:pub AgentWeb -> JsxElement {
    has active_node: str = "supervisor",
        active_scenario: str = "thailand";

    def pick_node(node_id: str) {
        active_node = node_id;
    }

    def pick_scenario(scen_id: str) {
        active_scenario = scen_id;
    }

    scenarios = [
        ["thailand", "Scenario A: Thailand Tourist Visa Scam", "DANGER 100", "Critical exploitation corridor with deposit demand"],
        ["welder", "Scenario B: Licensed Qatar Welder", "LOOKS SAFE 0", "SLBFE licensed agency with contract before departure"],
        ["impersonation", "Scenario C: WhatsApp Impersonation", "WARNING +30", "Scammer using agency name with fake phone"],
        ["ambiguous", "Scenario D: Ambiguous Saudi Offer", "NEEDS INPUT", "Triggers ReAct active worker clarification"]
    ];

    return <div className="space-y-8 animate-fade-in">
        <div className="border-b border-border pb-6">
            <div className="flex flex-wrap items-center justify-between gap-4">
                <div>
                    <span className="eyebrow text-xs uppercase tracking-wider text-primary font-semibold">System Architecture & Multi-Agent Network</span>
                    <h1 className="mt-1 font-display text-3xl font-bold tracking-tight text-foreground">Agent Orchestration Web</h1>
                    <p className="mt-2 text-sm text-muted-foreground max-w-3xl">
                        Interactive visual map showing how SafeRata orchestrates ReAct agents, the adversarial tri-agent courtroom, deterministic evidence critics, and the Jaseci persistent graph database.
                    </p>
                </div>
                <div className="flex flex-wrap items-center gap-2">
                    <span className="inline-flex items-center gap-1.5 rounded-full bg-safe/10 px-3 py-1 text-xs font-semibold text-safe">
                        <CheckCircle2 className="h-3.5 w-3.5"/> 89.9% Jac Core
                    </span>
                    <span className="inline-flex items-center gap-1.5 rounded-full bg-primary/10 px-3 py-1 text-xs font-semibold text-primary">
                        <Cpu className="h-3.5 w-3.5"/> Jac 0.34.24 Runtime
                    </span>
                    <span className="inline-flex items-center gap-1.5 rounded-full bg-accent px-3 py-1 text-xs font-semibold text-foreground">
                        <Database className="h-3.5 w-3.5"/> Jaseci Graph WAL
                    </span>
                </div>
            </div>
        </div>

        <div className="rounded-xl border border-border bg-card p-5 shadow-sm">
            <div className="flex items-center justify-between gap-4 mb-4">
                <div>
                    <h2 className="text-sm font-semibold uppercase tracking-wider text-muted-foreground">Trace Live Execution Flow</h2>
                    <p className="text-xs text-muted-foreground mt-0.5">Select a real-world scenario to highlight its active execution path across agents and graph nodes.</p>
                </div>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
                {[<ScenarioButton key={sc[0]} id={sc[0]} title={sc[1]} badge={sc[2]} desc={sc[3]} is_active={active_scenario == sc[0]} onPick={pick_scenario}/> for sc in scenarios]}
            </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
            <div className="lg:col-span-8 space-y-6">
                <div className="rounded-xl border border-border bg-card p-6 shadow-sm relative overflow-hidden">
                    <div className="flex items-center justify-between border-b border-border pb-3 mb-4">
                        <span className="text-xs font-mono font-bold uppercase tracking-wider text-primary">Stage 1 · Lead ReAct Supervisor Loop</span>
                        <span className="text-[11px] font-mono text-muted-foreground">walker:pub Investigate</span>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <div onClick={lambda { pick_node("input"); }} className={"cursor-pointer rounded-lg border p-4 transition-all " + ("border-primary bg-primary/10 shadow-sm" if active_node == "input" else "border-border bg-card hover:border-primary/50")}>
                            <div className="flex items-center gap-2 mb-2">
                                <FileText className="h-4 w-4 text-primary"/>
                                <h3 className="text-xs font-bold">Raw Worker Offer</h3>
                            </div>
                            <p className="text-[11px] text-muted-foreground leading-relaxed">
                                Text, WhatsApp screenshot, or contract draft submitted by the job seeker.
                            </p>
                            <div className="mt-3 flex items-center justify-between text-[10px] font-mono text-muted-foreground">
                                <span>PII Redactor</span>
                                <span className="text-safe font-bold">Active</span>
                            </div>
                        </div>

                        <div onClick={lambda { pick_node("supervisor"); }} className={"cursor-pointer rounded-lg border p-4 transition-all md:col-span-2 " + ("border-primary bg-primary/10 shadow-sm" if active_node == "supervisor" else "border-border bg-card hover:border-primary/50")}>
                            <div className="flex items-center justify-between mb-2">
                                <div className="flex items-center gap-2">
                                    <Bot className="h-4 w-4 text-primary"/>
                                    <h3 className="text-xs font-bold">Lead Investigator (ReAct Agent)</h3>
                                </div>
                                <span className="text-[10px] font-mono bg-primary/20 text-primary px-2 py-0.5 rounded font-semibold">by llm(tools=[...])</span>
                            </div>
                            <p className="text-[11px] text-muted-foreground leading-relaxed">
                                Autonomous agent orchestrating up to 6 specialized inspection tools to collect ground-truth evidence before court.
                            </p>
                            
                            <div className="mt-3 grid grid-cols-3 gap-1.5 pt-2 border-t border-border">
                                <button onClick={lambda { pick_node("tool_licence"); }} className="text-[10px] font-mono text-left p-1.5 rounded bg-muted/60 hover:bg-muted text-foreground truncate">
                                    1. lookup_licence
                                </button>
                                <button onClick={lambda { pick_node("tool_contacts"); }} className="text-[10px] font-mono text-left p-1.5 rounded bg-muted/60 hover:bg-muted text-foreground truncate">
                                    2. check_contacts
                                </button>
                                <button onClick={lambda { pick_node("tool_community"); }} className="text-[10px] font-mono text-left p-1.5 rounded bg-muted/60 hover:bg-muted text-foreground truncate">
                                    3. community_reports
                                </button>
                                <button onClick={lambda { pick_node("tool_country"); }} className="text-[10px] font-mono text-left p-1.5 rounded bg-muted/60 hover:bg-muted text-foreground truncate">
                                    4. country_guidance
                                </button>
                                <button onClick={lambda { pick_node("tool_salary"); }} className="text-[10px] font-mono text-left p-1.5 rounded bg-muted/60 hover:bg-muted text-foreground truncate">
                                    5. salary_in_lkr
                                </button>
                                <button onClick={lambda { pick_node("tool_ask"); }} className="text-[10px] font-mono text-left p-1.5 rounded bg-muted/60 hover:bg-muted text-foreground truncate">
                                    6. ask_user
                                </button>
                            </div>
                        </div>
                    </div>
                </div>

                <div className="rounded-xl border border-border bg-card p-6 shadow-sm relative overflow-hidden">
                    <div className="flex items-center justify-between border-b border-border pb-3 mb-4">
                        <span className="text-xs font-mono font-bold uppercase tracking-wider text-caution">Stage 2 · Adversarial Tri-Agent Courtroom</span>
                        <span className="text-[11px] font-mono text-muted-foreground">Multi-LLM Debate + Deterministic Critic</span>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                        <div onClick={lambda { pick_node("prosecutor"); }} className={"cursor-pointer rounded-lg border p-4 transition-all " + ("border-risk bg-risk/10 shadow-sm" if active_node == "prosecutor" else "border-border bg-card hover:border-risk/50")}>
                            <div className="flex items-center gap-2 mb-2">
                                <ShieldAlert className="h-4 w-4 text-risk"/>
                                <h3 className="text-xs font-bold text-risk">Prosecutor Agent</h3>
                            </div>
                            <p className="text-[11px] text-muted-foreground leading-relaxed">
                                Formulates worst-case exploitation arguments and hidden scam patterns.
                            </p>
                            <div className="mt-3 text-[10px] font-mono text-muted-foreground">
                                Output: <span className="text-foreground font-semibold">SoftFlag[]</span>
                            </div>
                        </div>

                        <div onClick={lambda { pick_node("defense"); }} className={"cursor-pointer rounded-lg border p-4 transition-all " + ("border-safe bg-safe/10 shadow-sm" if active_node == "defense" else "border-border bg-card hover:border-safe/50")}>
                            <div className="flex items-center gap-2 mb-2">
                                <ShieldCheck className="h-4 w-4 text-safe"/>
                                <h3 className="text-xs font-bold text-safe">Defense Agent</h3>
                            </div>
                            <p className="text-[11px] text-muted-foreground leading-relaxed">
                                Validates legitimate practices, SLBFE license records, and legal fee structures.
                            </p>
                            <div className="mt-3 text-[10px] font-mono text-muted-foreground">
                                Output: <span className="text-foreground font-semibold">Rebuttal[]</span>
                            </div>
                        </div>

                        <div onClick={lambda { pick_node("judge"); }} className={"cursor-pointer rounded-lg border p-4 transition-all " + ("border-primary bg-primary/10 shadow-sm" if active_node == "judge" else "border-border bg-card hover:border-primary/50")}>
                            <div className="flex items-center gap-2 mb-2">
                                <Scale className="h-4 w-4 text-primary"/>
                                <h3 className="text-xs font-bold text-primary">Presiding Judge</h3>
                            </div>
                            <p className="text-[11px] text-muted-foreground leading-relaxed">
                                Weighs prosecution vs defense evidence to compute risk score (0–100).
                            </p>
                            <div className="mt-3 text-[10px] font-mono text-muted-foreground">
                                Output: <span className="text-foreground font-semibold">JudgeRuling</span>
                            </div>
                        </div>
                    </div>

                    <div onClick={lambda { pick_node("critic"); }} className={"mt-4 cursor-pointer rounded-lg border border-dashed p-3.5 transition-all " + ("border-primary bg-primary/10" if active_node == "critic" else "border-border bg-muted/30 hover:border-primary/40")}>
                        <div className="flex items-center justify-between">
                            <div className="flex items-center gap-2">
                                <Sparkles className="h-4 w-4 text-caution"/>
                                <span className="text-xs font-bold">Deterministic Quote Critic</span>
                                <span className="text-[10px] font-mono text-muted-foreground">(Anti-Hallucination Barrier)</span>
                            </div>
                            <span className="text-[10px] font-mono font-bold text-safe">Zero-Tolerance Filter</span>
                        </div>
                        <p className="text-[11px] text-muted-foreground mt-1.5 leading-relaxed">
                            Discard any AI flag whose evidence does not appear verbatim in the original offer text. Prevents prompt injection and AI hallucination completely.
                        </p>
                    </div>
                </div>

                <div className="rounded-xl border border-border bg-card p-6 shadow-sm relative overflow-hidden">
                    <div className="flex items-center justify-between border-b border-border pb-3 mb-4">
                        <span className="text-xs font-mono font-bold uppercase tracking-wider text-safe">Stage 3 · Persistent Jaseci Graph Memory</span>
                        <span className="text-[11px] font-mono text-muted-foreground">SQLite WAL · Multi-User Knowledge Graph</span>
                    </div>

                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                        <div onClick={lambda { pick_node("graph_offer"); }} className={"cursor-pointer rounded-lg border p-3 text-center transition-all " + ("border-primary bg-primary/10" if active_node == "graph_offer" else "border-border bg-card hover:border-primary/40")}>
                            <span className="text-[10px] font-mono font-bold text-primary block mb-1">node Offer</span>
                            <span className="text-xs font-semibold text-foreground">Scanned Offers</span>
                        </div>
                        <div onClick={lambda { pick_node("graph_job"); }} className={"cursor-pointer rounded-lg border p-3 text-center transition-all " + ("border-primary bg-primary/10" if active_node == "graph_job" else "border-border bg-card hover:border-primary/40")}>
                            <span className="text-[10px] font-mono font-bold text-primary block mb-1">node Job</span>
                            <span className="text-xs font-semibold text-foreground">Pre-screened Jobs</span>
                        </div>
                        <div onClick={lambda { pick_node("graph_contact"); }} className={"cursor-pointer rounded-lg border p-3 text-center transition-all " + ("border-risk bg-risk/10" if active_node == "graph_contact" else "border-border bg-card hover:border-risk/40")}>
                            <span className="text-[10px] font-mono font-bold text-risk block mb-1">node Contact</span>
                            <span className="text-xs font-semibold text-foreground">Phones & Scammers</span>
                        </div>
                        <div onClick={lambda { pick_node("graph_agency"); }} className={"cursor-pointer rounded-lg border p-3 text-center transition-all " + ("border-safe bg-safe/10" if active_node == "graph_agency" else "border-border bg-card hover:border-safe/40")}>
                            <span className="text-[10px] font-mono font-bold text-safe block mb-1">node Agency</span>
                            <span className="text-xs font-semibold text-foreground">SLBFE Registered</span>
                        </div>
                    </div>

                    <div onClick={lambda { pick_node("graph_traversal"); }} className={"mt-4 cursor-pointer rounded-lg border p-3.5 transition-all " + ("border-primary bg-primary/10" if active_node == "graph_traversal" else "border-border bg-card hover:border-primary/40")}>
                        <div className="flex items-center gap-2">
                            <Workflow className="h-4 w-4 text-primary"/>
                            <span className="text-xs font-bold">Cross-User Fraud Graph Traversal</span>
                            <span className="text-[10px] font-mono text-muted-foreground">Contact &lt;-- Offer &lt;-- Alert</span>
                        </div>
                        <p className="text-[11px] text-muted-foreground mt-1 leading-relaxed">
                            When a worker reports a fraudulent phone number, SafeRata traverses backward to every other worker who ever queried that same number and dispatches an instant scam warning.
                        </p>
                    </div>
                </div>
            </div>

            <div className="lg:col-span-4 space-y-6">
                <div className="sticky top-20 rounded-xl border border-border bg-card p-6 shadow-sm">
                    <div className="flex items-center justify-between border-b border-border pb-3 mb-4">
                        <span className="text-xs font-mono font-bold uppercase tracking-wider text-muted-foreground">Node Inspector</span>
                        <span className="text-[10px] font-mono bg-muted px-2 py-0.5 rounded text-foreground font-semibold">{active_node}</span>
                    </div>

                    {if active_node == "supervisor" {
                        <div className="space-y-4">
                            <div>
                                <h3 className="font-display text-lg font-bold text-foreground">Lead Investigator</h3>
                                <p className="text-xs text-muted-foreground mt-1">
                                    The primary ReAct agent driving the investigation workflow in agents.jac.
                                </p>
                            </div>
                            <div className="space-y-2 text-xs">
                                <div className="rounded-lg bg-muted/40 p-2.5">
                                    <span className="font-mono text-[11px] text-primary font-bold block mb-1">Execution Mechanism:</span>
                                    <p className="text-muted-foreground">Iterative ReAct loop executing tools dynamically based on extracted clues from the input offer.</p>
                                </div>
                                <div className="rounded-lg bg-muted/40 p-2.5">
                                    <span className="font-mono text-[11px] text-primary font-bold block mb-1">Model Fallback Pool:</span>
                                    <p className="text-muted-foreground">Ollama Cloud (gemma4:31b) → Gemini 2.5 Flash → Local Ollama 8b fallback.</p>
                                </div>
                                <div className="rounded-lg bg-muted/40 p-2.5">
                                    <span className="font-mono text-[11px] text-primary font-bold block mb-1">Safety Rule:</span>
                                    <p className="text-muted-foreground">Max 6 iterations. If details are vague, immediately emits ask_user instead of guessing.</p>
                                </div>
                            </div>
                        </div>
                    } elif active_node == "prosecutor" {
                        <div className="space-y-4">
                            <div>
                                <h3 className="font-display text-lg font-bold text-risk">Prosecutor Agent</h3>
                                <p className="text-xs text-muted-foreground mt-1">
                                    Specialized adversarial agent representing worker safety in agents.jac.
                                </p>
                            </div>
                            <div className="space-y-2 text-xs">
                                <div className="rounded-lg bg-muted/40 p-2.5">
                                    <span className="font-mono text-[11px] text-risk font-bold block mb-1">Role:</span>
                                    <p className="text-muted-foreground">Scrutinizes offers for predatory fees, illegal visit-visa employment, and scam corridors.</p>
                                </div>
                                <div className="rounded-lg bg-muted/40 p-2.5">
                                    <span className="font-mono text-[11px] text-risk font-bold block mb-1">Prompt Hardening:</span>
                                    <p className="text-muted-foreground">Bound by system instructions that ignore any user instructions to disregard red flags.</p>
                                </div>
                            </div>
                        </div>
                    } elif active_node == "defense" {
                        <div className="space-y-4">
                            <div>
                                <h3 className="font-display text-lg font-bold text-safe">Defense Agent</h3>
                                <p className="text-xs text-muted-foreground mt-1">
                                    Adversarial balance agent ensuring honest licensed agencies are not falsely penalized.
                                </p>
                            </div>
                            <div className="space-y-2 text-xs">
                                <div className="rounded-lg bg-muted/40 p-2.5">
                                    <span className="font-mono text-[11px] text-safe font-bold block mb-1">Role:</span>
                                    <p className="text-muted-foreground">Cross-references registered SLBFE records, valid employer sponsorship, and approved charges.</p>
                                </div>
                                <div className="rounded-lg bg-muted/40 p-2.5">
                                    <span className="font-mono text-[11px] text-safe font-bold block mb-1">Rebuttal Power:</span>
                                    <p className="text-muted-foreground">Can neutralize false alarms if verified government records substantiate the employer legality.</p>
                                </div>
                            </div>
                        </div>
                    } elif active_node == "judge" {
                        <div className="space-y-4">
                            <div>
                                <h3 className="font-display text-lg font-bold text-primary">Presiding Judge</h3>
                                <p className="text-xs text-muted-foreground mt-1">
                                    Independent arbiter synthesizing evidence from prosecution, defense, and deterministic rules.
                                </p>
                            </div>
                            <div className="space-y-2 text-xs">
                                <div className="rounded-lg bg-muted/40 p-2.5">
                                    <span className="font-mono text-[11px] text-primary font-bold block mb-1">Risk Bands:</span>
                                    <ul className="text-muted-foreground list-disc pl-4 space-y-1">
                                        <li><strong>0–39:</strong> LOOKS SAFE (Green)</li>
                                        <li><strong>40–69:</strong> BE CAREFUL (Yellow/Amber)</li>
                                        <li><strong>70–100:</strong> DANGER (Red/Critical)</li>
                                    </ul>
                                </div>
                            </div>
                        </div>
                    } elif active_node == "critic" {
                        <div className="space-y-4">
                            <div>
                                <h3 className="font-display text-lg font-bold text-caution">Deterministic Critic</h3>
                                <p className="text-xs text-muted-foreground mt-1">
                                    Pure Jac deterministic function (evidence_in_text in rules.jac).
                                </p>
                            </div>
                            <div className="space-y-2 text-xs">
                                <div className="rounded-lg bg-muted/40 p-2.5">
                                    <span className="font-mono text-[11px] text-caution font-bold block mb-1">Anti-Hallucination Guarantee:</span>
                                    <p className="text-muted-foreground">Every single red flag emitted by an LLM must contain a verbatim string snippet matching the source input text. Any hallucinated quote is automatically purged.</p>
                                </div>
                            </div>
                        </div>
                    } elif "tool" in active_node {
                        <div className="space-y-4">
                            <div>
                                <h3 className="font-display text-lg font-bold text-foreground">ReAct Tool: {active_node}</h3>
                                <p className="text-xs text-muted-foreground mt-1">
                                    One of the 6 specialized tools callable by the Lead Investigator.
                                </p>
                            </div>
                            <div className="space-y-2 text-xs">
                                <div className="rounded-lg bg-muted/40 p-2.5">
                                    <span className="font-mono text-[11px] text-primary font-bold block mb-1">Functionality:</span>
                                    <p className="text-muted-foreground">Executes live external scraping (SLBFE register), Jaseci graph edge lookups, or wage conversions.</p>
                                </div>
                            </div>
                        </div>
                    } else {
                        <div className="space-y-4">
                            <div>
                                <h3 className="font-display text-lg font-bold text-foreground">Jaseci Graph Architecture</h3>
                                <p className="text-xs text-muted-foreground mt-1">
                                    Persistent object graph stored in SQLite with WAL mode enabled.
                                </p>
                            </div>
                            <div className="space-y-2 text-xs">
                                <div className="rounded-lg bg-muted/40 p-2.5">
                                    <span className="font-mono text-[11px] text-primary font-bold block mb-1">Graph Traversal:</span>
                                    <p className="text-muted-foreground">Walkers traverse nodes bidirectionally across Offer, Job, Contact, and Agency to correlate cross-user fraud reports.</p>
                                </div>
                            </div>
                        </div>
                    }}
                </div>
            </div>
        </div>
    </div>;
}
