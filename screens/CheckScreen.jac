"""Check: paste a suspicious message and get a verdict in seconds.

Check needs the client token. The browser asks for it once as an access
code and keeps it in localStorage on this device only.
"""

import from ..components.Icon {
    Icon
}
import from ..components.theme {
    TITLE,
    LEDE,
    BUTTON,
    PRIMARY,
    INPUT,
    ALERT
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
         {"value": "phone", "label": "A phone number", "icon": "phone"},
         {"value": "id", "label": "A name like MPESA", "icon": "badge"},
         {"value": "", "label": "Not sure", "icon": ""}
     ];


def:pub CheckScreen(lang: str) -> JsxElement {
    has text: str = "",
        fromKind: str = "",
        token: str = getToken(),
        result: dict[str, any] | None = None,
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
            result = (reply["reports"] as list[dict[str, any]])[0];
        } elif "forbidden" in failure {
            error = "That access code was not accepted.";
        } elif "rate_limited" in failure {
            error = "Too many checks right now. Try again in a minute.";
        } else {
            error = "The check could not finish: " + failure;
        }
    }

    fieldLabel = {"display": "block", "fontWeight": "700", "fontSize": "13px", "margin": "0 0 8px"};
    return <section>
        <h2 style={TITLE}>Check before you pay</h2>
        <p style={LEDE}>Paste any SMS that asks for money. You’ll get a verdict in seconds.</p>
        <form onSubmit={submit} style={{"display": "flex", "flexDirection": "column", "gap": "16px"}}>
            <div>
                <label htmlFor="check-text" style={fieldLabel}>The message</label>
                <textarea
                    id="check-text"
                    value={text}
                    onChange={lambda (e: ChangeEvent) { text = e.target.value; }}
                    rows={6}
                    maxLength={2000}
                    placeholder="e.g. Your loan is approved. Pay a Ksh 500 fee to till ..."
                    style={{
                        "display": "block",
                        "width": "100%",
                        "boxSizing": "border-box",
                        "fontSize": "16px",
                        "lineHeight": "1.5",
                        "padding": "14px",
                        "border": "none",
                        "borderRadius": "20px",
                        "backgroundColor": "#ffffff",
                        "boxShadow": "inset 0 0 0 1.5px #e8a33d",
                        "color": "#173232",
                        "resize": "vertical"
                    }}
                />
            </div>
            <fieldset style={{"border": "none", "padding": "0", "margin": "0"}}>
                <legend style={fieldLabel}>Who sent it?</legend>
                <div style={{"display": "flex", "flexWrap": "wrap", "gap": "8px"}}>
                    {for c in SENDER_CHOICES {
                        <button
                            key={c["label"]}
                            type="button"
                            aria-pressed={fromKind == c["value"]}
                            onClick={lambda { fromKind = c["value"]; }}
                            style={{
                                "minHeight": "44px",
                                "padding": "0 14px",
                                "display": "flex",
                                "alignItems": "center",
                                "gap": "8px",
                                "borderRadius": "14px",
                                "border": "none",
                                "fontSize": "14px",
                                "fontWeight": "500",
                                "cursor": "pointer",
                                "backgroundColor": "#e7f0ec" if fromKind == c["value"] else "#ffffff",
                                "color": "#0f3d3e" if fromKind == c["value"] else "#173232",
                                "boxShadow": "inset 0 0 0 2px #0f3d3e" if fromKind == c["value"] else "inset 0 0 0 1px #eadfc8"
                            }}
                        >
                            {if c["icon"] {
                                <Icon name={c["icon"]} size={16}/>
                            }}
                            {c["label"]}
                        </button>
                    }}
                </div>
            </fieldset>
            <div>
                <label htmlFor="check-token" style={fieldLabel}>Access code</label>
                <input
                    id="check-token"
                    type="password"
                    value={token}
                    autoComplete="off"
                    onChange={lambda (e: ChangeEvent) { token = e.target.value; }}
                    style={INPUT}
                />
            </div>
            <button
                type="submit"
                disabled={busy or not text.strip()}
                style={{**BUTTON, **PRIMARY, "opacity": "0.55" if busy or not text.strip() else "1"}}
            >
                <Icon name="check" color="#fbf6ec"/>
                {"Checking…" if busy else "Check message"}
            </button>
            <div style={{"display": "flex", "gap": "10px", "backgroundColor": "#fbecd0", "borderRadius": "16px", "padding": "12px 14px", "fontSize": "13px"}}>
                <Icon name="bulb" color="#8a5a0b"/>
                <span>Numbers, tills and names are hidden before the check runs.</span>
            </div>
        </form>
        {if error {
            <p role="alert" style={{**ALERT, "marginTop": "12px"}}>{error}</p>
        }}
        {if result {
            <div style={{"marginTop": "20px"}}>
                <VerdictPanel verdict={result} lang={lang} quote={result["display"]}/>
                <p style={{"margin": "12px 0 0", "fontSize": "12px", "color": "#6f817d", "textAlign": "center"}}>
                    Decision aid, not legal advice.
                </p>
            </div>
        }}
    </section>;
}
