"""A feed card: sender, risk (word + shape + colour), the masked message and,
once analysed, the first reason and any ring link. Tapping it opens the
message detail."""

import from "@jac/runtime" {
    Link
}
import from .RiskBadge {
    RiskBadge
}
import from .Icon {
    Icon
}
import from .theme {
    CARD,
    RISK
}


def:pub MessageCard(message: dict[str, any]) -> JsxElement {
    reasons = (message["reasons"] or []) as list[str];
    analysed = message["status"] == "analysed";
    tone = RISK[message["risk"]] if analysed and message["risk"] in RISK else {"bg": "#ece6d8", "fg": "#4a6260"};
    return <Link
        to={"/message/" + message["id"]}
        style={{
            **CARD,
            "display": "flex",
            "flexDirection": "column",
            "gap": "8px",
            "padding": "14px",
            "color": "inherit",
            "textDecoration": "none"
        }}
    >
        <div style={{"display": "flex", "alignItems": "center", "gap": "10px"}}>
            <span
                style={{
                    "width": "38px",
                    "height": "38px",
                    "borderRadius": "12px",
                    "display": "grid",
                    "placeItems": "center",
                    "flex": "none",
                    "backgroundColor": tone["bg"],
                    "color": tone["fg"]
                }}
            >
                <Icon name="phone"/>
            </span>
            <strong style={{"flex": "1", "minWidth": "0", "fontSize": "14px", "overflowWrap": "anywhere"}}>
                {message["sender_display"]}
            </strong>
            <RiskBadge risk={message["risk"]} status={message["status"]}/>
        </div>
        <p
            style={{
                "margin": "0",
                "color": "#4a6260",
                "fontSize": "14px",
                "lineHeight": "1.45",
                "overflowWrap": "anywhere",
                "display": "-webkit-box",
                "WebkitLineClamp": "2",
                "WebkitBoxOrient": "vertical",
                "overflow": "hidden"
            }}
        >
            {message["display"]}
        </p>
        {if analysed and len(reasons) > 0 {
            <div
                style={{
                    "display": "flex",
                    "gap": "8px",
                    "alignItems": "flex-start",
                    "fontSize": "13px",
                    "backgroundColor": "#fbf6ec",
                    "borderRadius": "12px",
                    "padding": "8px 10px"
                }}
            >
                <Icon name="stop" size={14} color={tone["fg"]}/>
                <span>{reasons[0]}</span>
            </div>
        }}
        {if message["ring_id"] or message["cached"] {
            <div style={{"display": "flex", "flexWrap": "wrap", "gap": "8px", "alignItems": "center"}}>
                {if message["ring_id"] {
                    <span style={{"display": "flex", "alignItems": "center", "gap": "6px", "fontSize": "12px", "fontWeight": "700", "color": "#b23a24"}}>
                        <Icon name="link" size={14}/>
                        Part of a scam ring
                    </span>
                }}
                {if message["cached"] {
                    <span
                        title="Replayed from the labelled demo set, not a live LLM call"
                        style={{"fontSize": "11px", "padding": "2px 8px", "borderRadius": "999px", "backgroundColor": "#ece6d8", "color": "#4a6260"}}
                    >
                        cached
                    </span>
                }}
            </div>
        }}
    </Link>;
}
