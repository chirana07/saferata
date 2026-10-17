"""Persistent community graph and the typed objects the agents exchange.

Root ─▶ Offer ─▶ Agency          (agency named in the offer, as found on the SLBFE register)
Root ─▶ Contact ◀─ Offer          (normalised phone / email shared by many offers)
Offer ─▶ Alert                    (raised when a linked offer is later judged Danger)
"""

node Agency {
    has licence_no: str,
        name: str,
        phones: list[str] = [],
        email: str = "",
        valid_upto: str = "",
        checked_at: str = "";
}

node Contact {
    has value: str,
        kind: str;
}

node Offer {
    has text: str,
        job: str = "",
        country: str = "",
        agency_name: str = "",
        verdict: str = "",
        score: int = 0,
        summary: str = "",
        created_at: str = "";
}

node Alert {
    has message: str,
        created_at: str;
}
