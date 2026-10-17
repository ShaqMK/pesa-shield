"""A Verdict's body: scam type, cached badge, at most three reasons, one
action, the explanation in the chosen language, and masked entities.

Renders with lookups and JSX loops only - Python string helpers on loosely
typed (dict) values do not survive the compile to JavaScript.
"""

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


def:pub VerdictPanel(verdict: dict, lang: str) -> JsxElement {
    scam = verdict["scam_type"] or "none";
    reasons = ((verdict["reasons"] or []) as list[str])[:3];
    entities = (verdict["entities"] or []) as list[dict];
    tools = (verdict["tools_used"] or []) as list[str];
    explanation = verdict["explanation_sw"] if lang == "sw" else verdict["explanation_en"];
    return <div style={{"fontSize": "0.92rem", "color": "#222"}}>
        <div style={{"display": "flex", "flexWrap": "wrap", "gap": "0.4rem", "alignItems": "center"}}>
            <span style={{"color": "#555"}}>{SCAM_LABELS[scam] or scam}</span>
            {if verdict["cached"] {
                <span
                    title="Replayed from the labelled demo set, not a live LLM call"
                    style={{
                        "fontSize": "0.72rem",
                        "padding": "0.1rem 0.45rem",
                        "borderRadius": "6px",
                        "border": "1px solid #999",
                        "color": "#444"
                    }}
                >
                    cached demo verdict
                </span>
            }}
        </div>
        {if verdict["escalated"] {
            <p style={{"margin": "0.5rem 0 0", "fontSize": "0.82rem", "color": "#a61b1b"}}>
                Risk raised: linked to a scam ring.
            </p>
        }}
        <h3 style={{"fontSize": "0.95rem", "margin": "0.8rem 0 0.3rem"}}>Why</h3>
        <ul style={{"margin": "0", "paddingLeft": "1.2rem"}}>
            {for (i, r) in enumerate(reasons) {
                <li key={str(i)} style={{"marginBottom": "0.25rem"}}>{r}</li>
            }}
        </ul>
        <div
            style={{
                "marginTop": "0.8rem",
                "padding": "0.65rem 0.75rem",
                "backgroundColor": "#eef3ff",
                "borderRadius": "8px"
            }}
        >
            <strong>Do this: </strong>{verdict["action"]}
        </div>
        <p style={{"margin": "0.8rem 0 0", "lineHeight": "1.45"}} lang={lang}>{explanation}</p>
        {if len(entities) > 0 {
            <div style={{"marginTop": "0.8rem", "fontSize": "0.82rem", "color": "#555"}}>
                Found (masked):
                {for (i, e) in enumerate(entities) {
                    <span key={str(i)}>{" "}{e["kind"]} {e["display"]}{"," if i + 1 < len(entities) else ""}</span>
                }}
            </div>
        }}
        {if "check_lender" in tools or scam == "fee_before_loan" {
            <div style={{"marginTop": "0.5rem", "fontSize": "0.78rem", "color": "#7a4f00"}}>
                Lender list: snapshot, verify before use with the regulator.
            </div>
        }}
        <p style={{"margin": "0.6rem 0 0", "fontSize": "0.75rem", "color": "#666"}}>
            Decision aid, not legal advice.
        </p>
    </div>;
}
