"""A Verdict: a risk-coloured hero (risk, scam type, the masked message), one
action, at most three reasons, the explanation in the chosen language, and
masked entities.

Renders with lookups and JSX loops only - Python string helpers on loosely
typed (dict[str, any]) values do not survive the compile to JavaScript.
"""

import from .theme {
    CARD,
    LABEL,
    RISK,
    DISPLAY
}
import from .Icon {
    Icon
}

glob SCAM_LABELS: dict[str, str] = {
    "wrong_number_reversal": "Wrong-number reversal",
    "fee_before_loan": "Fee before loan",
    "fake_prize_promo": "Fake prize or promotion",
    "fake_confirmation": "Fake payment confirmation",
    "impersonation": "Impersonation",
    "fake_job_or_visa_fee": "Fake job or visa fee",
    "sim_swap_otp_request": "SIM swap or code request",
    "legit_transaction": "Genuine transaction or notice",
    "none": "No scam pattern"
};


def:pub VerdictPanel(verdict: dict[str, any], lang: str, quote: str = "", sender: str = "") -> JsxElement {
    scam = verdict["scam_type"] or "none";
    reasons = ((verdict["reasons"] or []) as list[str])[:3];
    entities = (verdict["entities"] or []) as list[dict[str, any]];
    tools = (verdict["tools_used"] or []) as list[str];
    explanation = verdict["explanation_sw"] if lang == "sw" else verdict["explanation_en"];
    tone = RISK[verdict["risk"]] if verdict["risk"] in RISK else {"label": "Unknown", "icon": "circle", "bg": "#ece6d8", "fg": "#4a6260"};
    return <div style={{"display": "flex", "flexDirection": "column", "gap": "14px", "fontSize": "14.5px"}}>
        <div
            style={{
                "borderRadius": "26px",
                "padding": "20px",
                "backgroundColor": tone["bg"],
                "display": "flex",
                "flexDirection": "column",
                "gap": "10px"
            }}
        >
            <div
                style={{
                    "display": "flex",
                    "alignItems": "center",
                    "gap": "10px",
                    "fontFamily": DISPLAY,
                    "fontSize": "32px",
                    "fontWeight": "700",
                    "lineHeight": "1",
                    "color": tone["fg"]
                }}
            >
                <Icon name={tone["icon"]} size={28} color={tone["fg"]}/>
                {tone["label"]}
            </div>
            <div style={{"fontWeight": "500"}}>
                {SCAM_LABELS[scam] or scam}{(" · from " + sender) if sender else ""}
            </div>
            {if verdict["escalated"] {
                <div style={{"display": "flex", "alignItems": "center", "gap": "6px", "fontSize": "13px", "fontWeight": "700", "color": "#b23a24"}}>
                    <Icon name="link" size={14}/>
                    Risk raised: linked to a scam ring.
                </div>
            }}
            {if quote {
                <div
                    style={{
                        "backgroundColor": "rgba(255,255,255,0.7)",
                        "borderRadius": "14px",
                        "padding": "10px 12px",
                        "fontSize": "13.5px",
                        "fontStyle": "italic",
                        "color": "#4a6260",
                        "overflowWrap": "anywhere"
                    }}
                >
                    {quote}
                </div>
            }}
            {if verdict["cached"] {
                <span
                    title="Replayed from the labelled demo set, not a live LLM call"
                    style={{"alignSelf": "flex-start", "fontSize": "11px", "padding": "2px 8px", "borderRadius": "999px", "backgroundColor": "rgba(255,255,255,0.7)", "color": "#4a6260"}}
                >
                    cached demo verdict
                </span>
            }}
        </div>
        <div
            style={{
                "backgroundColor": "#0f3d3e",
                "color": "#fbf6ec",
                "borderRadius": "20px",
                "padding": "16px",
                "display": "flex",
                "gap": "12px"
            }}
        >
            <span
                style={{
                    "width": "36px",
                    "height": "36px",
                    "borderRadius": "12px",
                    "backgroundColor": "#e8a33d",
                    "display": "grid",
                    "placeItems": "center",
                    "flex": "none"
                }}
            >
                <Icon name="stop" size={20} color="#0f3d3e"/>
            </span>
            <div>
                <div style={{"fontSize": "11px", "fontWeight": "700", "letterSpacing": "0.1em", "textTransform": "uppercase", "color": "#f3c06b"}}>
                    Do this
                </div>
                <div style={{"fontSize": "15px", "fontWeight": "500", "lineHeight": "1.4"}}>{verdict["action"]}</div>
            </div>
        </div>
        {if len(reasons) > 0 {
            <div style={CARD}>
                <h3 style={LABEL}>Why</h3>
                <ul style={{"margin": "0", "padding": "0", "listStyle": "none", "display": "flex", "flexDirection": "column", "gap": "8px"}}>
                    {for (i, r) in enumerate(reasons) {
                        <li key={str(i)} style={{"display": "flex", "gap": "10px"}}>
                            <Icon name="cross" size={18} color={tone["fg"]}/>
                            <span>{r}</span>
                        </li>
                    }}
                </ul>
            </div>
        }}
        <div style={CARD}>
            <h3 style={LABEL}>{"Maelezo" if lang == "sw" else "Explanation"}</h3>
            <p style={{"margin": "0", "lineHeight": "1.55"}} lang={lang}>{explanation}</p>
        </div>
        {if len(entities) > 0 {
            <div style={CARD}>
                <h3 style={LABEL}>Found (masked)</h3>
                <div style={{"display": "flex", "flexWrap": "wrap", "gap": "6px"}}>
                    {for (i, e) in enumerate(entities) {
                        <span
                            key={str(i)}
                            style={{"display": "flex", "alignItems": "center", "gap": "6px", "backgroundColor": "#fbf6ec", "borderRadius": "10px", "padding": "6px 10px", "fontSize": "13px"}}
                        >
                            <span style={{"color": "#6f817d", "fontSize": "11px", "textTransform": "uppercase", "letterSpacing": "0.06em"}}>{e["kind"]}</span>
                            <strong>{e["display"]}</strong>
                        </span>
                    }}
                </div>
            </div>
        }}
        {if "check_lender" in tools or scam == "fee_before_loan" {
            <div style={{"fontSize": "13px", "color": "#8a5a0b", "backgroundColor": "#fbecd0", "borderRadius": "14px", "padding": "10px 12px"}}>
                Lender list: snapshot, verify before use with the regulator.
            </div>
        }}
    </div>;
}
