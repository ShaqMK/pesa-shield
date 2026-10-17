"""Risk as a word plus colour - never colour alone (GLOSSARY: Risk)."""

glob RISK_STYLE: dict[str, dict[str, str]] = {
    "high": {"label": "High risk", "bg": "#fde2e1", "fg": "#a61b1b"},
    "medium": {"label": "Medium risk", "bg": "#fff1d6", "fg": "#7a4f00"},
    "low": {"label": "Low risk", "bg": "#e3f5e8", "fg": "#1e6b3a"}
};


def:pub RiskBadge(risk: str, status: str = "analysed") -> JsxElement {
    style = RISK_STYLE[risk] if status == "analysed" and risk in RISK_STYLE else {
        "label": "check failed" if status == "failed" else (status or "unknown"),
        "bg": "#e0e0e0",
        "fg": "#444"
    };
    return <span
        style={{
            "display": "inline-block",
            "fontSize": "0.75rem",
            "fontWeight": "600",
            "padding": "0.2rem 0.55rem",
            "borderRadius": "999px",
            "whiteSpace": "nowrap",
            "backgroundColor": style["bg"],
            "color": style["fg"]
        }}
    >
        {style["label"]}
    </span>;
}
