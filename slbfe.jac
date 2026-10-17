"""Live lookup against the official SLBFE licensed-agency register.

Source: https://applications.slbfe.lk/feb/la/la_main.asp (public search form).
The register lists only valid agencies and agencies with pending renewals, so
"not found" means "not on the official register today".
"""
import re;
import html;
import urllib.request;
import urllib.parse;
import os;
import ssl;
import from datetime { datetime }

glob SLBFE_URL = "https://applications.slbfe.lk/feb/la/la_details.asp";

obj AgencyRecord {
    has licence_no: str,
        name: str,
        licencee: str = "",
        address: str = "",
        phones: list[str] = [],
        email: str = "",
        valid_upto: str = "";
}

obj RegisterResult {
    has ok: bool,
        records: list[AgencyRecord] = [],
        error: str = "",
        source: str = SLBFE_URL,
        checked_at: str = "";
}

"""Keep digits only and use the local 0XXXXXXXXX form, so +94 77... matches 077..."""
def normalise_phone(raw: str) -> str {
    digits = re.sub(r"\D", "", raw);
    if digits.startswith("94") and len(digits) == 11 {
        digits = "0" + digits[2:];
    }
    if len(digits) == 9 and not digits.startswith("0") {
        digits = "0" + digits;
    }
    return digits;
}

def _clean(s: str) -> str {
    return re.sub(r"\s+", " ", html.unescape(s)).strip();
}

def _field(chunk: str, label: str, stop: str) -> str {
    pattern: str = "(?s)" + label + "\\s*:?\\s*(.*?)\\s*" + stop;
    hits: list[str] = re.findall(pattern, chunk);
    return _clean(hits[0]) if hits else "";
}

"""Turn the register's HTML page into agency records."""
def parse_register(page: str) -> list[AgencyRecord] {
    text = re.sub(r"<[^>]+>", "\n", page);
    text = html.unescape(text);
    lines = [_clean(l) for l in text.split("\n")];
    flat = "\n".join([l for l in lines if l]);
    records: list[AgencyRecord] = [];
    parts = re.split(r"\(Labour\s+Licence No :", flat);
    for i in range(1, len(parts)) {
        before = parts[i - 1].strip().split("\n");
        name: str = str(before[-1]).strip() if before else "";
        chunk = parts[i];
        num = re.match(r"\s*(\d+)", chunk);
        if not num {
            continue;
        }
        phones_raw = _field(chunk, r"Telephone\s*\n?:", r"\nFax");
        phones = [normalise_phone(p) for p in re.split(r"[,/ ]+", phones_raw) if len(re.sub(r"\D", "", p)) >= 9];
        email = _field(chunk, r"Email\s*\n?:", r"\n");
        records.append(
            AgencyRecord(
                licence_no=num.group(1),
                name=name,
                licencee=_field(chunk, r"Licencee:", r"\nAddress"),
                address=_field(chunk, r"Address:", r"\nTelephone"),
                phones=phones,
                email="" if email == "***" else email.lower(),
                valid_upto=_field(chunk, r"Valid upto :", r"\n")
            )
        );
    }
    return records;
}

"""HTTPS context: certifi's bundle if installed, else the OS bundle (some jac runtimes ship no CA certs)."""
def _ssl_context -> ssl.SSLContext {
    paths: list[str] = ["/etc/ssl/cert.pem", "/etc/ssl/certs/ca-certificates.crt", "/etc/pki/tls/certs/ca-bundle.crt"];
    try {
        import certifi;
        paths.insert(0, str(certifi.where()));
    } except Exception {}
    for p in paths {
        if os.path.exists(p) {
            return ssl.create_default_context(cafile=p);
        }
    }
    return ssl.create_default_context();
}

def _post(form: dict[str, str]) -> RegisterResult {
    now = datetime.now().strftime("%Y-%m-%d %H:%M");
    try {
        data = urllib.parse.urlencode(form).encode();
        req = urllib.request.Request(SLBFE_URL, data=data, headers={"User-Agent": "SafeRata/0.1 (hackathon demo)"});
        resp = urllib.request.urlopen(req, timeout=15, context=_ssl_context());
        page: str = resp.read().decode("latin-1");
        resp.close();
        return RegisterResult(ok=True, records=parse_register(page), checked_at=now);
    } except Exception as e {
        return RegisterResult(ok=False, error=str(e), checked_at=now);
    }
}

"""Search the register by licence number (the number printed on genuine ads)."""
def search_by_licence(licence_no: str) -> RegisterResult {
    digits = re.sub(r"\D", "", licence_no);
    if not digits {
        return RegisterResult(ok=True, records=[], checked_at=datetime.now().strftime("%Y-%m-%d %H:%M"));
    }
    return _post({"an": digits, "agency": "", "address": "", "District": "", "country": "", "Search": "Search"});
}

"""Search the register by any part of the agency name."""
def search_by_name(name: str) -> RegisterResult {
    n = name.strip();
    if not n {
        return RegisterResult(ok=True, records=[], checked_at=datetime.now().strftime("%Y-%m-%d %H:%M"));
    }
    return _post({"an": "", "agency": n, "address": "", "District": "", "country": "", "Search223": "Search"});
}

with entry:__main__ {
    r = search_by_licence("3500");
    print(r.ok, r.error, len(r.records));
    for a in r.records {
        print(a);
    }
    r2 = search_by_name("GLOBAL");
    print("name search:", r2.ok, len(r2.records), r2.records[0] if r2.records else None);
    print("missing licence:", len(search_by_licence("9998").records));
    print(normalise_phone("+94 77 160 5640"), normalise_phone("771605640"));
}
