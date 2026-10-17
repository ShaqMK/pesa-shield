"""Cases: every Recovery case, newest first."""

import from react {
    useEffect
}
import from "@jac/runtime" {
    Link
}
import from ..components.Icon {
    Icon
}
import from ..components.theme {
    CARD,
    TITLE,
    LEDE,
    ALERT,
    MUTED
}
import from ..services.api {
    callWalker
}

glob STATUS_WORDS: dict[str, str] = {
    "awaiting_approval": "Awaiting your approval",
    "approved": "Approved, ready to copy",
    "discarded": "Discarded"
};


def:pub CasesScreen() -> JsxElement {
    has cases: list[dict[str, any]] = [],
        loaded: bool = False,
        error: str = "";

    async def loadCases -> None {
        reply = await callWalker("ListCases", {});
        error = str(reply["error"]);
        if not error {
            cases = reply["reports"] as list[dict[str, any]];
            loaded = True;
        }
    }

    useEffect(lambda { loadCases(); }, []);

    return <section style={{"display": "flex", "flexDirection": "column", "gap": "12px"}}>
        <div>
            <h2 style={TITLE}>Cases</h2>
            <p style={{**LEDE, "margin": "0"}}>
                Lost money? Open the message in the Feed and tap "I lost money".
                Pesa Shield drafts a report for you to approve; nothing is ever sent for you.
            </p>
        </div>
        {if error {
            <p role="alert" style={ALERT}>{error}</p>
        }}
        {if len(cases) == 0 {
            <p style={MUTED}>{"No cases yet." if loaded else "Loading…"}</p>
        }}
        {for c in cases {
            <Link
                key={c["id"]}
                to={"/cases/" + c["id"]}
                style={{**CARD, "display": "flex", "alignItems": "center", "gap": "12px", "color": "inherit", "textDecoration": "none"}}
            >
                <span
                    style={{
                        "width": "40px",
                        "height": "40px",
                        "borderRadius": "12px",
                        "display": "grid",
                        "placeItems": "center",
                        "flex": "none",
                        "backgroundColor": "#fbecd0" if c["status"] == "awaiting_approval" else "#e7f0ec",
                        "color": "#8a5a0b" if c["status"] == "awaiting_approval" else "#0f3d3e"
                    }}
                >
                    <Icon name="case" size={20}/>
                </span>
                <div style={{"flex": "1", "minWidth": "0"}}>
                    <strong style={{"display": "block", "fontSize": "15px"}}>{STATUS_WORDS[c["status"]] or c["status"]}</strong>
                    <span style={{"fontSize": "13px", "color": "#6f817d"}}>{str(c["messages"])} message(s)</span>
                </div>
            </Link>
        }}
    </section>;
}
