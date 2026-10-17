"""Cases: every Recovery case, newest first."""

import from react {
    useEffect
}
import from "@jac/runtime" {
    Link
}
import from ..services.api {
    callWalker
}

glob STATUS_WORDS: dict[str, str] = {
    "awaiting_approval": "Awaiting your approval",
    "approved": "Approved - ready to copy",
    "discarded": "Discarded"
};


def:pub CasesScreen() -> JsxElement {
    has cases: list[dict] = [],
        loaded: bool = False,
        error: str = "";

    async def loadCases -> None {
        reply = await callWalker("ListCases", {});
        error = str(reply["error"]);
        if not error {
            cases = reply["reports"] as list[dict];
            loaded = True;
        }
    }

    useEffect(lambda { loadCases(); }, []);

    return <section>
        <h2 style={{"fontSize": "1.05rem", "margin": "0 0 0.3rem"}}>Cases</h2>
        <p style={{"color": "#666", "fontSize": "0.82rem", "margin": "0 0 0.8rem"}}>
            Lost money? Open the message in the Feed and tap "I lost money".
            Pesa Shield drafts a report for you to approve; nothing is ever sent for you.
        </p>
        {if error {
            <p role="alert" style={{"color": "#a61b1b"}}>{error}</p>
        }}
        {if len(cases) == 0 {
            <p style={{"color": "#888", "fontSize": "0.9rem"}}>{"No cases yet." if loaded else "Loading…"}</p>
        }}
        {for c in cases {
            <Link
                key={c["id"]}
                to={"/cases/" + c["id"]}
                style={{
                    "display": "block",
                    "minHeight": "44px",
                    "padding": "0.7rem 0.9rem",
                    "marginBottom": "0.5rem",
                    "border": "1px solid #e3e6ea",
                    "borderRadius": "10px",
                    "backgroundColor": "#f8f9fa",
                    "color": "inherit",
                    "textDecoration": "none"
                }}
            >
                <strong>{STATUS_WORDS[c["status"]] or c["status"]}</strong>
                <div style={{"fontSize": "0.82rem", "color": "#555"}}>
                    {str(c["messages"])} message(s)
                </div>
            </Link>
        }}
    </section>;
}
