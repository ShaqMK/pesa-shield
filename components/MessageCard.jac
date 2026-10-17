"""A feed card: sender, risk (word + colour), the masked message and, once
analysed, the first reason. Tapping it opens the message detail."""

import from "@jac/runtime" {
    Link
}
import from .RiskBadge {
    RiskBadge
}


def:pub MessageCard(message: dict[str, any]) -> JsxElement {
    reasons = (message["reasons"] or []) as list[str];
    return <Link
        to={"/message/" + message["id"]}
        style={{
            "display": "block",
            "minHeight": "44px",
            "padding": "0.7rem 0.9rem",
            "marginBottom": "0.5rem",
            "backgroundColor": "#f8f9fa",
            "border": "1px solid #e3e6ea",
            "borderRadius": "10px",
            "color": "inherit",
            "textDecoration": "none"
        }}
    >
        <div style={{"display": "flex", "justifyContent": "space-between", "gap": "0.5rem"}}>
            <strong style={{"fontSize": "0.82rem"}}>{message["sender_display"]}</strong>
            <span>
                <RiskBadge risk={message["risk"]} status={message["status"]}/>
                {if message["cached"] {
                    <span
                        title="Replayed from the labelled demo set, not a live LLM call"
                        style={{
                            "marginLeft": "0.3rem",
                            "fontSize": "0.7rem",
                            "padding": "0.05rem 0.35rem",
                            "borderRadius": "6px",
                            "border": "1px solid #999",
                            "color": "#444"
                        }}
                    >
                        cached
                    </span>
                }}
            </span>
        </div>
        <p style={{"margin": "0.35rem 0 0", "color": "#333", "fontSize": "0.88rem", "overflowWrap": "anywhere"}}>
            {message["display"]}
        </p>
        {if message["status"] == "analysed" and len(reasons) > 0 {
            <p style={{"margin": "0.35rem 0 0", "color": "#555", "fontSize": "0.8rem"}}>{reasons[0]}</p>
        }}
    </Link>;
}
