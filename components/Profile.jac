"""Worker profile (kept only in this browser) used by MatchJobs to rank listings. Safety is never affected by it."""

import from .theme { INK, MUTED_INK, PRIMARY, MUTED, BORDER, CARD, LABEL }

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
    has name: str = "",
        occupation: str = "",
        skills: str = "",
        experience: str = "0",
        destinations: str = "",
        min_salary: str = "150000",
        accommodation: bool = True,
        saved: str = "";

    can with entry {
        name = prof("name", "");
        occupation = prof("occupation", "");
        skills = prof("skills", "");
        experience = prof("experience", "0");
        destinations = prof("destinations", "");
        min_salary = prof("min_salary", "150000");
        accommodation = prof("accommodation", "yes") == "yes";
    }

    def save {
        put("name", name);
        put("occupation", occupation);
        put("skills", skills);
        put("experience", experience);
        put("destinations", destinations);
        put("min_salary", min_salary);
        put("accommodation", "yes" if accommodation else "no");
        put("saved", "yes");
        saved = "Saved in this browser. Discover now ranks listings for you.";
    }

    inp = {"width": "100%", "boxSizing": "border-box", "padding": "9px", "borderRadius": "8px", "border": "1px solid " + BORDER, "marginTop": "4px", "fontFamily": "inherit"};

    return <div style={{"display": "grid", "gridTemplateColumns": "minmax(0, 7fr) minmax(0, 5fr)", "gap": "18px", "alignItems": "start"}}>
        <div style={CARD}>
            <h1 style={{"fontSize": "30px", "margin": "0 0 4px"}}>{"Tell us what "}<span style={{"color": PRIMARY}}>{"you're good at."}</span></h1>
            <p style={{"color": MUTED_INK, "marginTop": "0"}}>Used only to rank listings on Discover. Stored in this browser, never on our server.</p>
            <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "10px"}}>
                <label style={{"fontSize": "13px"}}>Preferred name<input value={name} onChange={lambda (e: ChangeEvent) { name = e.target.value; }} style={inp}/></label>
                <label style={{"fontSize": "13px"}}>Occupation<input placeholder="e.g. Driver, Chef, Caregiver" value={occupation} onChange={lambda (e: ChangeEvent) { occupation = e.target.value; }} style={inp}/></label>
                <label style={{"fontSize": "13px"}}>Skills (comma separated)<input placeholder="e.g. Gulf licence, NVQ Level 3" value={skills} onChange={lambda (e: ChangeEvent) { skills = e.target.value; }} style={inp}/></label>
                <label style={{"fontSize": "13px"}}>Years of experience<input value={experience} onChange={lambda (e: ChangeEvent) { experience = e.target.value; }} style={inp}/></label>
                <label style={{"fontSize": "13px"}}>Preferred destinations (comma separated)<input placeholder="e.g. Qatar, Japan" value={destinations} onChange={lambda (e: ChangeEvent) { destinations = e.target.value; }} style={inp}/></label>
                <label style={{"fontSize": "13px"}}>Minimum monthly salary (LKR)<input value={min_salary} onChange={lambda (e: ChangeEvent) { min_salary = e.target.value; }} style={inp}/></label>
            </div>
            <label style={{"display": "flex", "gap": "8px", "alignItems": "center", "marginTop": "12px", "fontSize": "14px"}}>
                <input type="checkbox" checked={accommodation} onChange={lambda (e: ChangeEvent) { accommodation = e.target.checked; }}/>I need accommodation provided
            </label>
            <button onClick={lambda -> None { save(); }}
                style={{"marginTop": "14px", "background": PRIMARY, "color": "white", "border": "none", "borderRadius": "10px", "padding": "11px 18px", "fontWeight": "700"}}>Save profile</button>
            {if saved {
                <p style={{"color": "#1d8a55", "marginBottom": "0"}}>{saved}</p>
            }}
        </div>
        <div style={CARD}>
            <div style={LABEL}>How this is used</div>
            <ul style={{"paddingLeft": "18px", "fontSize": "14px"}}>
                <li>Occupation and skills set your match score.</li>
                <li>Destinations and salary decide what is recommended first.</li>
                <li>Your profile never changes a job's safety assessment.</li>
                <li>We never ask for your NIC, passport, religion or family details.</li>
            </ul>
        </div>
    </div>;
}
