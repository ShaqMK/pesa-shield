"""Live feed, newest first; polls every 4s while mounted. A summary card counts
the verdicts in the feed, and chips filter it by risk or ring."""

import from react {
    useEffect
}
import from ..components.MessageCard {
    MessageCard
}
import from ..components.Icon {
    Icon
}
import from ..components.theme {
    DISPLAY,
    STRIPE,
    ALERT,
    MUTED
}
import from ..services.api {
    callWalker
}

glob FILTERS: list[dict[str, str]] = [
    {"id": "all", "label": "All"},
    {"id": "high", "label": "High risk"},
    {"id": "ring", "label": "In a ring"}
];


"""Messages the chosen chip keeps."""
def keep(m: dict[str, any], chosen: str) -> bool {
    if chosen == "high" {
        return m["status"] == "analysed" and m["risk"] == "high";
    }
    if chosen == "ring" {
        return True if m["ring_id"] else False;
    }
    return True;
}


"""How many analysed messages carry this risk."""
def countRisk(messages: list[dict[str, any]], risk: str) -> int {
    return len([m for m in messages if m["status"] == "analysed" and m["risk"] == risk]);
}


def SummaryCard(messages: list[dict[str, any]]) -> JsxElement {
    high = countRisk(messages, "high");
    tiles = [
        {"label": "High", "icon": "triangle", "color": "#ffb8a8", "count": str(high)},
        {"label": "Medium", "icon": "diamond", "color": "#f3c06b", "count": str(countRisk(messages, "medium"))},
        {"label": "Low", "icon": "circle", "color": "#9fdcbb", "count": str(countRisk(messages, "low"))}
    ];
    return <div
        style={{
            "position": "relative",
            "overflow": "hidden",
            "borderRadius": "26px",
            "padding": "20px 20px 26px",
            "color": "#fbf6ec",
            "background": "radial-gradient(circle at 90% 0%, #2a7a73 0%, #1d5f5c 30%, #0f3d3e 70%)"
        }}
    >
        <span
            style={{
                "position": "absolute",
                "top": "16px",
                "right": "16px",
                "display": "flex",
                "alignItems": "center",
                "gap": "6px",
                "fontSize": "11px",
                "fontWeight": "700",
                "backgroundColor": "rgba(251,246,236,0.14)",
                "borderRadius": "999px",
                "padding": "4px 10px"
            }}
        >
            <span style={{"width": "7px", "height": "7px", "borderRadius": "50%", "backgroundColor": "#7fd6a6"}}/>
            Guard is on
        </span>
        <div style={{"fontSize": "12px", "letterSpacing": "0.1em", "textTransform": "uppercase", "color": "#f3c06b", "fontWeight": "700"}}>
            In your feed
        </div>
        <div style={{"fontFamily": DISPLAY, "fontSize": "40px", "fontWeight": "700", "lineHeight": "1.05", "margin": "6px 0 2px"}}>
            {str(len(messages))} checked
        </div>
        <div style={{"fontSize": "13px", "color": "#cfe3dd"}}>
            {("No high-risk messages right now." if high == 0 else (str(high) + " flagged high risk. Don't pay them."))}
        </div>
        <div style={{"display": "grid", "gridTemplateColumns": "repeat(3, 1fr)", "gap": "8px", "marginTop": "16px"}}>
            {for t in tiles {
                <div key={t["label"]} style={{"backgroundColor": "rgba(251,246,236,0.1)", "borderRadius": "14px", "padding": "8px 10px"}}>
                    <strong style={{"display": "block", "fontSize": "20px"}}>{t["count"]}</strong>
                    <span style={{"display": "flex", "alignItems": "center", "gap": "5px", "fontSize": "11px", "color": "#cfe3dd"}}>
                        <Icon name={t["icon"]} size={10} color={t["color"]}/>
                        {t["label"]}
                    </span>
                </div>
            }}
        </div>
        <div style={{"position": "absolute", "left": "0", "right": "0", "bottom": "0", "height": "6px", "background": STRIPE}}/>
    </div>;
}


def:pub FeedScreen() -> JsxElement {
    has messages: list[dict[str, any]] = [],
        loaded: bool = False,
        error: str = "",
        chosen: str = "all";

    async def loadFeed -> None {
        reply = await callWalker("WebFeed", {"limit": 50});
        error = str(reply["error"]);
        if not error {
            messages = reply["reports"] as list[dict[str, any]];
            loaded = True;
        }
    }

    useEffect(lambda {
        loadFeed();
        interval = setInterval(lambda { loadFeed(); }, 4000);
        return lambda { clearInterval(interval); };
    }, []);

    shown = [m for m in messages if keep(m, chosen)];

    return <section style={{"display": "flex", "flexDirection": "column", "gap": "14px"}}>
        <SummaryCard messages={messages}/>
        <div role="group" aria-label="Filter messages" style={{"display": "flex", "gap": "8px", "overflowX": "auto"}}>
            {for f in FILTERS {
                <button
                    key={f["id"]}
                    type="button"
                    aria-pressed={chosen == f["id"]}
                    onClick={lambda { chosen = f["id"]; }}
                    style={{
                        "flex": "none",
                        "minHeight": "40px",
                        "padding": "0 16px",
                        "borderRadius": "999px",
                        "fontSize": "13px",
                        "fontWeight": "500",
                        "cursor": "pointer",
                        "border": "1px solid " + ("#173232" if chosen == f["id"] else "#eadfc8"),
                        "backgroundColor": "#173232" if chosen == f["id"] else "#ffffff",
                        "color": "#fbf6ec" if chosen == f["id"] else "#4a6260"
                    }}
                >
                    {f["label"]}
                </button>
            }}
        </div>
        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "baseline"}}>
            <h2 style={{"margin": "0", "fontFamily": DISPLAY, "fontSize": "19px", "color": "#0f3d3e"}}>Latest messages</h2>
            <span style={{"fontSize": "12px", "color": "#6f817d"}}>updates live</span>
        </div>
        {if error {
            <p role="alert" style={ALERT}>{error}</p>
        }}
        {if len(shown) == 0 {
            <p style={MUTED}>
                {("No messages yet. Forward an SMS to start." if chosen == "all" else "No messages match this filter.") if loaded else "Loading…"}
            </p>
        }}
        {for msg in shown {
            <MessageCard key={msg["id"]} message={msg}/>
        }}
    </section>;
}
