"""Design tokens taken from the layout-coder prototype (oklch values converted to hex)."""

glob:pub BG = "#eef3fb";
glob:pub INK = "#1b2236";
glob:pub MUTED_INK = "#646d86";
glob:pub PRIMARY = "#3d5af1";
glob:pub PRIMARY_DEEP = "#2b3bb5";
glob:pub ACCENT = "#e1e8fb";
glob:pub MUTED = "#e9eef7";
glob:pub BORDER = "#dde3ef";
glob:pub RISK = "#e0475a";
glob:pub RISK_SOFT = "#fcebee";
glob:pub WARN = "#c27c0e";
glob:pub WARN_SOFT = "#fdf3e1";
glob:pub OK = "#1d8a55";
glob:pub OK_SOFT = "#e5f5ec";

glob:pub CARD: dict[str, str] = {"background": "#ffffff", "border": "1px solid #dde3ef", "borderRadius": "14px", "padding": "18px"};
glob:pub LABEL: dict[str, str] = {"fontSize": "12px", "fontWeight": "600", "color": "#646d86", "textTransform": "uppercase", "letterSpacing": "0.04em"};

def:pub band_label(band: str) -> str {
    if band == "DANGER" {
        return "High risk";
    }
    if band == "BE CAREFUL" {
        return "Moderate risk";
    }
    if band == "LOOKS SAFE" {
        return "Low risk";
    }
    return "Not assessed";
}

def:pub band_fg(band: str) -> str {
    if band == "DANGER" {
        return "#e0475a";
    }
    if band == "BE CAREFUL" {
        return "#c27c0e";
    }
    return "#1d8a55";
}

def:pub band_bg(band: str) -> str {
    if band == "DANGER" {
        return "#fcebee";
    }
    if band == "BE CAREFUL" {
        return "#fdf3e1";
    }
    return "#e5f5ec";
}

def:pub trust_color(source: str) -> str {
    if "register" in source {
        return "#3d5af1";
    }
    if "guidance" in source {
        return "#0f766e";
    }
    if "community" in source {
        return "#7c3aed";
    }
    if "Salary" in source {
        return "#b45309";
    }
    return "#646d86";
}
