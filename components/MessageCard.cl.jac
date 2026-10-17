"""A single feed message card: the masked message and, once Guard is done,
its Verdict. Risk is always shown as a word plus colour, never colour alone.
"""

glob RISK_STYLE: dict[str, dict[str, str]] = {
    "high": {"label": "High risk", "bg": "#fde2e1", "fg": "#a61b1b"},
    "medium": {"label": "Medium risk", "bg": "#fff1d6", "fg": "#7a4f00"},
    "low": {"label": "Low risk", "bg": "#e3f5e8", "fg": "#1e6b3a"}
};


def:pub MessageCard(
    display: str,
    senderDisplay: str,
    status: str,
    risk: str = "",
    scamType: str = "",
    reasons: list[str] = [],
    action: str = "",
    explanation: str = "",
    cached: bool = False
) -> JsxElement {
    style = RISK_STYLE[risk] if status == "analysed" and risk in RISK_STYLE else {
        "label": "check failed" if status == "failed" else status,
        "bg": "#e0e0e0",
        "fg": "#555"
    };
    return <div
        style={{
            "padding": "0.7rem 0.9rem",
            "marginBottom": "0.5rem",
            "backgroundColor": "#f8f9fa",
            "border": "1px solid #e9ecef",
            "borderRadius": "10px",
            "minHeight": "44px"
        }}
    >
        <div style={{"display": "flex", "justifyContent": "space-between", "gap": "0.5rem"}}>
            <strong style={{"fontSize": "0.82rem"}}>{senderDisplay}</strong>
            <span
                style={{
                    "fontSize": "0.72rem",
                    "fontWeight": "600",
                    "padding": "0.15rem 0.5rem",
                    "borderRadius": "999px",
                    "backgroundColor": style["bg"],
                    "color": style["fg"]
                }}
            >
                {style["label"]}
            </span>
        </div>
        <p style={{"margin": "0.35rem 0 0", "color": "#333", "fontSize": "0.88rem"}}>{display}</p>
        {if status == "analysed" {
            <div style={{"marginTop": "0.45rem", "fontSize": "0.8rem", "color": "#333"}}>
                <div style={{"color": "#666"}}>
                    {" ".join(scamType.split("_")) if scamType != "none" else "no scam pattern"}
                    {" · cached" if cached else ""}
                </div>
                <ul style={{"margin": "0.3rem 0", "paddingLeft": "1.1rem"}}>
                    {for (i, r) in enumerate(reasons) {
                        <li key={str(i)}>{r}</li>
                    }}
                </ul>
                <div><strong>Do this: </strong>{action}</div>
                <p style={{"margin": "0.35rem 0 0", "color": "#555"}}>{explanation}</p>
            </div>
        }}
    </div>;
}
