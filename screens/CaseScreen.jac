"""One Recovery case: timeline, facts, recipients and the draft report, with
approve / save edits / discard. Approved text is shown for copying - Pesa
Shield never sends it."""

import from react {
    useEffect
}
import from "@jac/runtime" {
    Link,
    useParams
}
import from ..services.api {
    callWalker
}
import from ..services.token {
    getToken,
    saveToken
}

glob STATUS_WORDS: dict[str, str] = {
    "awaiting_approval": "Awaiting your approval",
    "approved": "Approved",
    "discarded": "Discarded"
},
     BUTTON: dict[str, str] = {
         "minHeight": "48px",
         "flex": "1",
         "borderRadius": "8px",
         "fontSize": "0.95rem",
         "fontWeight": "600"
     };


def:pub CaseScreen(lang: str) -> JsxElement {
    params = useParams();
    caseId = params["id"] or "";
    has data: dict[str, any] | None = None,
        draftEn: str = "",
        draftSw: str = "",
        chosen: list[str] = [],
        token: str = getToken(),
        busy: bool = False,
        notice: str = "",
        error: str = "";

    def adopt(view: dict[str, any]) {
        data = view;
        draftEn = str(view["body_en"]);
        draftSw = str(view["body_sw"]);
        chosen = view["recipients"] as list[str];
    }

    async def loadCase -> None {
        reply = await callWalker("GetCase", {"case_id": caseId});
        if reply["error"] {
            error = str(reply["error"]);
            return;
        }
        adopt((reply["reports"] as list[dict[str, any]])[0]);
    }

    async def act(walkerName: str, body: dict[str, any]) -> bool {
        if not token.strip() {
            error = "Enter your access code first.";
            return False;
        }
        saveToken(token);
        busy = True;
        error = "";
        notice = "";
        reply = await callWalker(walkerName, {**body, "token": token.strip(), "case_id": caseId});
        busy = False;
        failure = str(reply["error"]);
        if failure {
            error = "That access code was not accepted." if "forbidden" in failure else failure;
            return False;
        }
        adopt((reply["reports"] as list[dict[str, any]])[0]);
        return True;
    }

    async def saveEdits -> None {
        if await act("EditCase", {"body_en": draftEn, "body_sw": draftSw, "recipients": chosen}) {
            notice = "Draft saved. It is still awaiting your approval.";
        }
    }

    async def approve -> None {
        # Persist anything changed on screen first; unchanged fields are no-ops.
        if await act("EditCase", {"body_en": draftEn, "body_sw": draftSw, "recipients": chosen}) {
            if await act("ApproveCase", {}) {
                notice = "Approved. Copy the report below and send it yourself.";
            }
        }
    }

    async def discard -> None {
        if window.confirm("Discard this draft report?") {
            await act("DiscardCase", {});
        }
    }

    async def copyText -> None {
        shown = data as dict[str, any];
        text = shown["final_text_sw"] if lang == "sw" else shown["final_text_en"];
        clip: any = navigator.clipboard;
        await clip.writeText(text);
        notice = "Copied.";
    }

    def toggleRecipient(label: str) {
        chosen = [r for r in chosen if r != label] if label in chosen else chosen + [label];
    }

    useEffect(lambda { loadCase(); }, [caseId]);

    if error and not data {
        return <section>
            <Link to="/cases" style={{"display": "inline-flex", "minHeight": "44px", "alignItems": "center", "color": "#1a3fb0", "textDecoration": "none"}}>← Cases</Link>
            <p role="alert" style={{"color": "#a61b1b"}}>{error}</p>
        </section>;
    }
    if not data {
        return <p style={{"color": "#888"}}>Loading…</p>;
    }
    view = data as dict[str, any];
    isPending = view["status"] == "awaiting_approval";
    timeline = view["timeline"] as list[dict[str, any]];
    facts = view["facts"] as list[dict[str, any]];
    available = view["available_recipients"] as list[str];

    return <section>
        <Link to="/cases" style={{"display": "inline-flex", "minHeight": "44px", "alignItems": "center", "color": "#1a3fb0", "textDecoration": "none"}}>← Cases</Link>
        <h2 style={{"fontSize": "1.05rem", "margin": "0 0 0.2rem"}}>{STATUS_WORDS[view["status"]] or view["status"]}</h2>
        <p style={{"fontSize": "0.8rem", "color": "#666", "margin": "0 0 0.8rem"}}>
            Pesa Shield never sends this report. Decision aid, not legal advice.
            {" "}{"Draft written from a template." if view["drafted_by"] == "template" else ""}
        </p>

        <h3 style={{"fontSize": "0.95rem", "margin": "0.6rem 0 0.3rem"}}>What happened</h3>
        <ol style={{"margin": "0", "paddingLeft": "1.2rem", "fontSize": "0.85rem"}}>
            {for (i, t) in enumerate(timeline) {
                <li key={str(i)} style={{"marginBottom": "0.35rem", "overflowWrap": "anywhere"}}>
                    <span style={{"color": "#666"}}>{t["at"]}</span>{" "}{t["summary"]}
                </li>
            }}
        </ol>

        <h3 style={{"fontSize": "0.95rem", "margin": "0.8rem 0 0.3rem"}}>Facts (as in the messages, masked)</h3>
        <ul style={{"margin": "0", "paddingLeft": "1.2rem", "fontSize": "0.85rem"}}>
            {for (i, f) in enumerate(facts) {
                <li key={str(i)}>{f["kind"]}: <strong>{f["value"]}</strong></li>
            }}
        </ul>

        <h3 style={{"fontSize": "0.95rem", "margin": "0.8rem 0 0.3rem"}}>Send to (you send it)</h3>
        {for label in available {
            <label
                key={label}
                style={{"display": "flex", "gap": "0.5rem", "alignItems": "center", "minHeight": "44px", "fontSize": "0.85rem"}}
            >
                <input
                    type="checkbox"
                    checked={label in chosen}
                    disabled={not isPending}
                    onChange={lambda (e: ChangeEvent) { toggleRecipient(label); }}
                    style={{"width": "22px", "height": "22px"}}
                />
                {label}
            </label>
        }}
        <p style={{"fontSize": "0.75rem", "color": "#7a4f00", "margin": "0.2rem 0 0"}}>
            Reporting channels are placeholder labels: snapshot, verify before use.
        </p>

        <h3 style={{"fontSize": "0.95rem", "margin": "0.8rem 0 0.3rem"}}>
            {"Ripoti (Kiswahili)" if lang == "sw" else "Report (English)"}
        </h3>
        {if isPending {
            <textarea
                value={draftSw if lang == "sw" else draftEn}
                onChange={lambda (e: ChangeEvent) {
                    if lang == "sw" { draftSw = e.target.value; } else { draftEn = e.target.value; }
                }}
                rows={12}
                lang={lang}
                style={{"width": "100%", "boxSizing": "border-box", "fontSize": "16px", "padding": "0.6rem", "border": "1px solid #bbb", "borderRadius": "8px"}}
            />
        } else {
            <textarea
                readOnly={True}
                value={(view["final_text_sw"] if lang == "sw" else view["final_text_en"]) or "(discarded)"}
                rows={14}
                lang={lang}
                style={{"width": "100%", "boxSizing": "border-box", "fontSize": "15px", "padding": "0.6rem", "border": "1px solid #bbb", "borderRadius": "8px", "backgroundColor": "#f8f9fa"}}
            />
        }}

        {if isPending {
            <div>
                <label style={{"display": "block", "fontWeight": "600", "margin": "0.6rem 0 0.3rem"}}>
                    Access code
                    <input
                        type="password"
                        value={token}
                        autoComplete="off"
                        onChange={lambda (e: ChangeEvent) { token = e.target.value; }}
                        style={{"display": "block", "width": "100%", "boxSizing": "border-box", "minHeight": "44px", "fontSize": "16px", "marginTop": "0.3rem", "padding": "0 0.6rem", "border": "1px solid #bbb", "borderRadius": "8px"}}
                    />
                </label>
                <div style={{"display": "flex", "gap": "0.5rem", "marginTop": "0.6rem"}}>
                    <button type="button" disabled={busy} onClick={lambda { approve(); }}
                        style={{**BUTTON, "border": "none", "backgroundColor": "#1a3fb0", "color": "#fff"}}>
                        Approve
                    </button>
                    <button type="button" disabled={busy} onClick={lambda { saveEdits(); }}
                        style={{**BUTTON, "border": "1px solid #1a3fb0", "backgroundColor": "#fff", "color": "#1a3fb0"}}>
                        Save edits
                    </button>
                    <button type="button" disabled={busy} onClick={lambda { discard(); }}
                        style={{**BUTTON, "border": "1px solid #a61b1b", "backgroundColor": "#fff", "color": "#a61b1b"}}>
                        Discard
                    </button>
                </div>
            </div>
        } elif view["status"] == "approved" {
            <button type="button" onClick={lambda { copyText(); }}
                style={{**BUTTON, "width": "100%", "marginTop": "0.6rem", "border": "none", "backgroundColor": "#1a3fb0", "color": "#fff"}}>
                Copy report
            </button>
        }}
        {if notice {
            <p role="status" style={{"color": "#1e6b3a", "marginTop": "0.6rem"}}>{notice}</p>
        }}
        {if error {
            <p role="alert" style={{"color": "#a61b1b", "marginTop": "0.6rem"}}>{error}</p>
        }}
    </section>;
}
