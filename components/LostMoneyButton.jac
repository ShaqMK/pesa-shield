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
import from .theme {
    BUTTON,
    INPUT,
    ALERT
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
            navigate("/cases/" + (reply["reports"] as list[dict[str, any]])[0]["id"]);
        } elif "forbidden" in failure {
            askToken = True;
            error = "That access code was not accepted.";
        } else {
            error = "Could not start a case: " + failure;
        }
    }

    return <div style={{"display": "flex", "flexDirection": "column", "gap": "8px", "marginTop": "14px"}}>
        {if askToken {
            <label style={{"display": "flex", "flexDirection": "column", "gap": "6px", "fontWeight": "700", "fontSize": "13px"}}>
                Access code
                <input
                    type="password"
                    value={token}
                    autoComplete="off"
                    onChange={lambda (e: ChangeEvent) { token = e.target.value; }}
                    style={INPUT}
                />
            </label>
        }}
        <button
            type="button"
            onClick={lambda { start(); }}
            disabled={busy}
            style={{**BUTTON, "backgroundColor": "transparent", "color": "#b23a24", "boxShadow": "inset 0 0 0 1.5px #b23a24"}}
        >
            {"Building your case…" if busy else "I lost money"}
        </button>
        <p style={{"fontSize": "12px", "color": "#6f817d", "margin": "0", "textAlign": "center"}}>
            Builds a timeline and a draft report for you to review. Nothing is sent.
        </p>
        {if error {
            <p role="alert" style={ALERT}>{error}</p>
        }}
    </div>;
}
