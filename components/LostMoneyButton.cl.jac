"""'I lost money' - starts a Recovery case from a message and opens it.
Asks for the access code (client token) first if this device has none."""

import from "@jac/runtime" {
    useNavigate
}
import from ..services.api {
    callWalker
}
import from ..services.token {
    getToken,
    saveToken
}


def:pub LostMoneyButton(messageId: str) -> JsxElement {
    navigate = useNavigate();
    has token: str = getToken(),
        askToken: bool = False,
        busy: bool = False,
        error: str = "";

    async def start -> None {
        if not token.strip() {
            askToken = True;
            return;
        }
        saveToken(token);
        busy = True;
        error = "";
        reply = await callWalker("StartCase", {"token": token.strip(), "message_id": messageId}, 120000);
        busy = False;
        failure = str(reply["error"]);
        if not failure {
            navigate("/cases/" + (reply["reports"] as list[dict])[0]["id"]);
        } elif "forbidden" in failure {
            askToken = True;
            error = "That access code was not accepted.";
        } else {
            error = "Could not start a case: " + failure;
        }
    }

    return <div style={{"marginTop": "1.2rem", "borderTop": "1px solid #e3e6ea", "paddingTop": "0.9rem"}}>
        {if askToken {
            <label style={{"display": "block", "fontWeight": "600", "marginBottom": "0.3rem"}}>
                Access code
                <input
                    type="password"
                    value={token}
                    autoComplete="off"
                    onChange={lambda e: ChangeEvent { token = e.target.value; }}
                    style={{
                        "display": "block",
                        "width": "100%",
                        "boxSizing": "border-box",
                        "minHeight": "44px",
                        "fontSize": "16px",
                        "marginTop": "0.3rem",
                        "padding": "0 0.6rem",
                        "border": "1px solid #bbb",
                        "borderRadius": "8px"
                    }}
                />
            </label>
        }}
        <button
            type="button"
            onClick={lambda -> None { start(); }}
            disabled={busy}
            style={{
                "width": "100%",
                "minHeight": "48px",
                "marginTop": "0.5rem",
                "border": "1px solid #a61b1b",
                "borderRadius": "8px",
                "backgroundColor": "#fff",
                "color": "#a61b1b",
                "fontSize": "1rem",
                "fontWeight": "600"
            }}
        >
            {"Building your case…" if busy else "I lost money"}
        </button>
        <p style={{"fontSize": "0.78rem", "color": "#666", "margin": "0.4rem 0 0"}}>
            Builds a timeline and a draft report for you to review. Nothing is sent.
        </p>
        {if error {
            <p role="alert" style={{"color": "#a61b1b"}}>{error}</p>
        }}
    </div>;
}
