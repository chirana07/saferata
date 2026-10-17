"""Work profile (kept only in this browser), ported from the layout-coder design. Feeds MatchJobs; never affects safety."""

import from .ui { PageHeader }

glob STEPS: list[str] = ["Occupation", "Experience", "Destinations & pay", "Preferences"];
glob COUNTRIES: list[str] = ["Qatar", "Saudi Arabia", "United Arab Emirates", "Kuwait", "Oman", "Malaysia", "Japan", "South Korea", "Israel"];
glob INPUT = "mt-1 h-11 w-full rounded-md border border-input bg-card px-3 text-sm font-normal focus:border-primary";

"""Read one profile field from this browser (empty default if missing or storage is blocked)."""
def:pub prof(key: str, fallback: str) -> str {
    v: str = "";
    try {
        v = localStorage.getItem("saferata.p." + key) or "";
    } except Exception {
        v = "";
    }
    return v if v else fallback;
}

def put(key: str, value: str) {
    try {
        localStorage.setItem("saferata.p." + key, value);
    } except Exception {}
}

def:pub Profile -> JsxElement {
    has step: int = 0,
        name: str = "",
        occupation: str = "",
        skills: str = "",
        experience: str = "0",
        qualifications: str = "",
        destinations: list[str] = [],
        min_salary: str = "150000",
        accommodation: bool = True,
        preferences: str = "",
        saved: str = "";

    can with entry {
        name = prof("name", "");
        occupation = prof("occupation", "");
        skills = prof("skills", "");
        experience = prof("experience", "0");
        qualifications = prof("qualifications", "");
        destinations = [x.strip() for x in prof("destinations", "").split(",") if x.strip()];
        min_salary = prof("min_salary", "150000");
        accommodation = prof("accommodation", "yes") == "yes";
        preferences = prof("preferences", "");
    }

    def save {
        put("name", name);
        put("occupation", occupation);
        put("skills", skills);
        put("experience", experience);
        put("qualifications", qualifications);
        put("destinations", ", ".join(destinations));
        put("min_salary", min_salary);
        put("accommodation", "yes" if accommodation else "no");
        put("preferences", preferences);
        put("saved", "yes");
        saved = "Preferences saved in this browser. Discover now shows your match on every listing.";
    }

    def toggle_dest(c: str) {
        destinations = [d for d in destinations if d != c] if c in destinations else destinations + [c];
    }

    filled = len([x for x in [occupation, skills, experience != "0", qualifications, len(destinations) > 0, min_salary, preferences, name] if x]);
    pct = int(100 * filled / 8);

    return <div>
        <PageHeader eyebrow="Work profile" title="Tell us what" accent="you're good at.">
            <div className="w-48"><div className="flex justify-between text-xs"><span className="eyebrow">Complete</span><span className="font-mono font-semibold">{f"{pct}%"}</span></div><div className="mt-1 h-1.5 rounded-sm bg-secondary"><div className="h-full rounded-sm bg-primary transition-all" style={{"width": f"{pct}%"}}></div></div></div>
        </PageHeader>
        <div className="grid gap-10 lg:grid-cols-[200px_1fr_260px]">
            <ol className="flex gap-2 overflow-x-auto lg:flex-col">
                {[<li key={s}><button onClick={lambda -> None { step = i; }} className={"flex w-full items-center gap-3 whitespace-nowrap rounded-md px-3 py-2 text-left text-sm font-medium " + ("bg-card text-foreground shadow-card" if step == i else "text-muted-foreground")}><span className="font-mono text-xs">{f"0{i + 1}"}</span>{s}</button></li> for (i, s) in enumerate(STEPS)]}
            </ol>
            <div className="space-y-5 rise-in">
                {if step == 0 {
                    <div className="space-y-5">
                        <label className="block text-sm font-semibold">Preferred name<input value={name} onChange={lambda (e: ChangeEvent) { name = e.target.value; }} className={INPUT}/></label>
                        <label className="block text-sm font-semibold">Occupation<input value={occupation} onChange={lambda (e: ChangeEvent) { occupation = e.target.value; }} placeholder="e.g. Driver, Chef, Caregiver" className={INPUT}/></label>
                        <label className="block text-sm font-semibold">Skills <span className="font-normal text-muted-foreground">(comma separated)</span><input value={skills} onChange={lambda (e: ChangeEvent) { skills = e.target.value; }} className={INPUT}/></label>
                    </div>
                } elif step == 1 {
                    <div className="space-y-5">
                        <label className="block text-sm font-semibold">Years of experience<input type="number" value={experience} onChange={lambda (e: ChangeEvent) { experience = e.target.value; }} className={INPUT}/></label>
                        <label className="block text-sm font-semibold">Qualifications<input value={qualifications} onChange={lambda (e: ChangeEvent) { qualifications = e.target.value; }} placeholder="e.g. NVQ Level 3, JLPT N4" className={INPUT}/></label>
                    </div>
                } elif step == 2 {
                    <div className="space-y-5">
                        <div className="text-sm font-semibold">Preferred destinations
                            <div className="mt-2 flex flex-wrap gap-2">{[<button key={c} onClick={lambda -> None { toggle_dest(c); }} className={"h-9 rounded-md border px-3 text-sm font-medium " + ("border-primary bg-primary text-primary-foreground" if c in destinations else "border-border bg-card hover:border-primary")}>{c}</button> for c in COUNTRIES]}</div>
                        </div>
                        <label className="block text-sm font-semibold">Minimum monthly salary (LKR)<input type="number" value={min_salary} onChange={lambda (e: ChangeEvent) { min_salary = e.target.value; }} className={INPUT}/></label>
                        <label className="flex items-center gap-2 text-sm font-semibold"><input type="checkbox" checked={accommodation} onChange={lambda (e: ChangeEvent) { accommodation = e.target.checked; }} className="h-4 w-4 accent-[var(--primary)]"/> I need accommodation provided</label>
                    </div>
                } else {
                    <div className="space-y-5">
                        <label className="block text-sm font-semibold">Work preferences or constraints<textarea rows={3} value={preferences} onChange={lambda (e: ChangeEvent) { preferences = e.target.value; }} placeholder="e.g. Day shifts only, want to return home for Avurudu" className="mt-1 w-full rounded-md border border-input bg-card px-3 py-2 text-sm font-normal"/></label>
                    </div>
                }}
                <div className="flex gap-2 border-t border-border pt-5">
                    {if step > 0 { <button onClick={lambda -> None { step = step - 1; }} className="h-11 rounded-md border border-border bg-card px-4 text-sm font-semibold">Back</button> }}
                    <button onClick={lambda -> None { if step < 3 { step = step + 1; } else { save(); } }} className="h-11 rounded-md bg-primary px-5 text-sm font-semibold text-primary-foreground hover:bg-primary-deep">{"Continue" if step < 3 else "Save preferences"}</button>
                    {if step < 3 { <button onClick={lambda -> None { save(); }} className="h-11 px-3 text-sm font-semibold text-muted-foreground">Save now</button> }}
                </div>
                {if saved { <p className="text-sm font-medium text-safe">{saved}</p> }}
            </div>
            <aside className="h-fit rounded-xl bg-ink p-5 text-sm text-ink-foreground">
                <p className="eyebrow text-sky">How this is used</p>
                <ul className="mt-3 space-y-2 text-ink-foreground/80">
                    <li>Occupation and skills set your match score.</li>
                    <li>Destinations and salary filter what we recommend first.</li>
                    <li>{"Your profile never changes a job's safety assessment."}</li>
                    <li>We never ask for your NIC, passport, religion or family details.</li>
                    <li>Stored only in this browser; sent to the matcher per request, never saved on the server.</li>
                </ul>
            </aside>
        </div>
    </div>;
}
