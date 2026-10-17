"""Check: paste a suspicious message and get a verdict in seconds.

Check needs the client token. The browser asks for it once as an access
code and keeps it in localStorage on this device only.
"""

import from ..components.RiskBadge {
    RiskBadge
}
import from ..components.VerdictPanel {
    VerdictPanel
}
import from ..services.api {
    callWalker
}
import from ..services.token {
    getToken,
    saveToken
}

glob SENDER_CHOICES: list[dict[str, str]] = [
         {"value": "phone", "label": "A phone number"},
         {"value": "id", "label": "A name like MPESA"},
         {"value": "", "label": "Not sure"}
     ];


def:pub CheckScreen(lang: str) -> JsxElement {
    has text: str = "",
        fromKind: str = "",
        token: str = getToken(),
        result: dict | None = None,
        error: str = "",
        busy: bool = False;

    async def submit(e: FormEvent) -> None {
        e.preventDefault();
        if busy or not text.strip() {
            return;
        }
        if not token.strip() {
            error = "Enter your access code first.";
            return;
        }
        saveToken(token);
        busy = True;
        error = "";
        result = None;
        reply = await callWalker(
            "Check", {"token": token.strip(), "text": text, "from_kind": fromKind}
        );
        busy = False;
        failure = str(reply["error"]);
        if not failure {
            result = (reply["reports"] as list[dict])[0];
        } elif "forbidden" in failure {
            error = "That access code was not accepted.";
        } elif "rate_limited" in failure {
            error = "Too many checks right now. Try again in a minute.";
        } else {
            error = "The check could not finish: " + failure;
        }
    }

    return <section>
        <form onSubmit={submit}>
            <label style={{"display": "block", "fontWeight": "600", "marginBottom": "0.3rem"}}>
                Paste the message
            </label>
            <textarea
                value={text}
                onChange={lambda e: ChangeEvent { text = e.target.value; }}
                rows={6}
                maxLength={2000}
                placeholder="e.g. Your loan is approved. Pay a Ksh 500 fee to till ..."
                style={{
                    "width": "100%",
                    "boxSizing": "border-box",
                    "fontSize": "16px",
                    "padding": "0.6rem",
                    "border": "1px solid #bbb",
                    "borderRadius": "8px"
                }}
            />
            <fieldset style={{"border": "none", "padding": "0", "margin": "0.7rem 0"}}>
                <legend style={{"fontWeight": "600", "marginBottom": "0.3rem"}}>Who sent it?</legend>
                <div style={{"display": "flex", "flexWrap": "wrap", "gap": "0.4rem"}}>
                    {for c in SENDER_CHOICES {
                        <button
                            key={c["label"]}
                            type="button"
                            aria-pressed={fromKind == c["value"]}
                            onClick={lambda -> None { fromKind = c["value"]; }}
                            style={{
                                "minHeight": "44px",
                                "padding": "0 0.8rem",
                                "borderRadius": "22px",
                                "border": "1px solid " + ("#1a3fb0" if fromKind == c["value"] else "#bbb"),
                                "backgroundColor": "#eef3ff" if fromKind == c["value"] else "#fff",
                                "fontSize": "0.9rem"
                            }}
                        >
                            {c["label"]}
                        </button>
                    }}
                </div>
            </fieldset>
            <label style={{"display": "block", "fontWeight": "600", "marginBottom": "0.3rem"}}>
                Access code
            </label>
            <input
                type="password"
                value={token}
                autoComplete="off"
                onChange={lambda e: ChangeEvent { token = e.target.value; }}
                style={{
                    "width": "100%",
                    "boxSizing": "border-box",
                    "minHeight": "44px",
                    "fontSize": "16px",
                    "padding": "0 0.6rem",
                    "border": "1px solid #bbb",
                    "borderRadius": "8px"
                }}
            />
            <button
                type="submit"
                disabled={busy or not text.strip()}
                style={{
                    "width": "100%",
                    "minHeight": "48px",
                    "marginTop": "0.8rem",
                    "border": "none",
                    "borderRadius": "8px",
                    "backgroundColor": "#1a3fb0" if not busy else "#7d8fcf",
                    "color": "#fff",
                    "fontSize": "1rem",
                    "fontWeight": "600"
                }}
            >
                {"Checking…" if busy else "Check message"}
            </button>
        </form>
        {if error {
            <p role="alert" style={{"color": "#a61b1b", "marginTop": "0.8rem"}}>{error}</p>
        }}
        {if result {
            <div style={{"marginTop": "1rem", "padding": "0.8rem", "border": "1px solid #e3e6ea", "borderRadius": "10px"}}>
                <div style={{"marginBottom": "0.5rem"}}>
                    <RiskBadge risk={result["risk"]}/>
                </div>
                <p style={{"margin": "0 0 0.6rem", "fontSize": "0.82rem", "color": "#555", "overflowWrap": "anywhere"}}>
                    Checked (masked): {result["display"]}
                </p>
                <VerdictPanel verdict={result} lang={lang}/>
            </div>
        }}
    </section>;
}
