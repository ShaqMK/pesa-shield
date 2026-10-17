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
import from ..components.Icon {
    Icon
}
import from ..components.theme {
    CARD,
    LABEL,
    TITLE,
    BACK,
    BUTTON,
    PRIMARY,
    QUIET,
    INPUT,
    ALERT,
    MUTED
}
import from ..services.token {
    getToken,
    saveToken
}

glob STATUS_WORDS: dict[str, str] = {
    "awaiting_approval": "Waiting for your approval",
    "approved": "Approved, ready to copy",
    "discarded": "Discarded"
},
     STEPS: list[str] = ["Started", "Facts", "Draft", "Approve", "You send"],
     TEXTAREA: dict[str, str] = {
         "display": "block",
         "width": "100%",
         "boxSizing": "border-box",
         "fontSize": "15px",
         "lineHeight": "1.5",
         "padding": "12px",
         "border": "none",
         "borderRadius": "14px",
         "backgroundColor": "#fbf6ec",
         "boxShadow": "inset 0 0 0 1px #eadfc8",
         "color": "#173232"
     };


"""Index of the step the case is on: Approve while pending, You send once approved."""
def currentStep(status: str) -> int {
    return 4 if status == "approved" else 3;
}


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
            <Link to="/cases" style={BACK}><Icon name="back"/>Cases</Link>
            <p role="alert" style={ALERT}>{error}</p>
        </section>;
    }
    if not data {
        return <p style={MUTED}>Loading…</p>;
    }
    view = data as dict[str, any];
    isPending = view["status"] == "awaiting_approval";
    timeline = view["timeline"] as list[dict[str, any]];
    facts = view["facts"] as list[dict[str, any]];
    available = view["available_recipients"] as list[str];
    step = currentStep(str(view["status"]));

    return <section style={{"display": "flex", "flexDirection": "column", "gap": "14px"}}>
        <Link to="/cases" style={BACK}><Icon name="back"/>Cases</Link>
        <div style={{"display": "flex", "flexDirection": "column", "gap": "8px"}}>
            <span
                style={{
                    "alignSelf": "flex-start",
                    "display": "flex",
                    "alignItems": "center",
                    "gap": "6px",
                    "fontWeight": "700",
                    "fontSize": "13px",
                    "borderRadius": "999px",
                    "padding": "6px 12px",
                    "backgroundColor": "#fbecd0" if isPending else ("#dff0e5" if view["status"] == "approved" else "#ece6d8"),
                    "color": "#8a5a0b" if isPending else ("#22694a" if view["status"] == "approved" else "#4a6260")
                }}
            >
                <Icon name={"diamond" if isPending else ("tick" if view["status"] == "approved" else "stop")} size={12}/>
                {STATUS_WORDS[view["status"]] or view["status"]}
            </span>
            <h2 style={{**TITLE, "fontSize": "24px", "margin": "0"}}>Recovery case</h2>
            {if view["status"] != "discarded" {
                <div aria-label={"Step " + str(step + 1) + " of 5: " + STEPS[step]} style={{"display": "grid", "gridTemplateColumns": "repeat(5, 1fr)", "gap": "4px"}}>
                    {for (i, label) in enumerate(STEPS) {
                        <div key={label} style={{"display": "flex", "flexDirection": "column", "gap": "6px", "fontSize": "11px", "textAlign": "center", "color": "#173232" if i == step else "#6f817d", "fontWeight": "700" if i == step else "400"}}>
                            <span style={{"height": "6px", "borderRadius": "999px", "backgroundColor": "#e8a33d" if i == step else ("#0f3d3e" if i < step else "#eadfc8")}}/>
                            {label}
                        </div>
                    }}
                </div>
            }}
            <p style={{"fontSize": "13px", "color": "#6f817d", "margin": "0"}}>
                Pesa Shield never sends this report. Decision aid, not legal advice.
                {" "}{"Draft written from a template." if view["drafted_by"] == "template" else ""}
            </p>
        </div>

        <div style={CARD}>
            <h3 style={LABEL}>What happened</h3>
            <ol style={{"margin": "0", "padding": "0", "listStyle": "none", "display": "flex", "flexDirection": "column", "gap": "10px"}}>
                {for (i, t) in enumerate(timeline) {
                    <li key={str(i)} style={{"display": "flex", "gap": "10px", "fontSize": "14px", "overflowWrap": "anywhere"}}>
                        <span style={{"width": "10px", "height": "10px", "borderRadius": "50%", "backgroundColor": "#0f3d3e", "marginTop": "5px", "flex": "none"}}/>
                        <span style={{"minWidth": "0"}}>
                            <span style={{"display": "block", "color": "#6f817d", "fontSize": "12px"}}>{t["at"]}</span>
                            {t["summary"]}
                        </span>
                    </li>
                }}
            </ol>
        </div>

        <div style={CARD}>
            <h3 style={LABEL}>Facts (as in the messages, masked)</h3>
            <ul style={{"margin": "0", "padding": "0", "listStyle": "none", "display": "flex", "flexDirection": "column", "gap": "6px", "fontSize": "14px"}}>
                {for (i, f) in enumerate(facts) {
                    <li key={str(i)} style={{"display": "flex", "justifyContent": "space-between", "gap": "12px"}}>
                        <span style={{"color": "#6f817d"}}>{f["kind"]}</span>
                        <strong style={{"overflowWrap": "anywhere", "textAlign": "right"}}>{f["value"]}</strong>
                    </li>
                }}
            </ul>
        </div>

        <div style={CARD}>
            <h3 style={LABEL}>Send to (you send it)</h3>
            <div style={{"display": "flex", "flexDirection": "column", "gap": "8px"}}>
                {for label in available {
                    <label
                        key={label}
                        style={{
                            "display": "flex",
                            "gap": "10px",
                            "alignItems": "center",
                            "minHeight": "44px",
                            "padding": "6px 12px",
                            "borderRadius": "14px",
                            "fontSize": "14px",
                            "backgroundColor": "#e7f0ec" if label in chosen else "#fbf6ec",
                            "color": "#0f3d3e" if label in chosen else "#4a6260"
                        }}
                    >
                        <input
                            type="checkbox"
                            checked={label in chosen}
                            disabled={not isPending}
                            onChange={lambda (e: ChangeEvent) { toggleRecipient(label); }}
                            style={{"width": "20px", "height": "20px", "accentColor": "#0f3d3e", "flex": "none"}}
                        />
                        {label}
                    </label>
                }}
            </div>
            <p style={{"fontSize": "12px", "color": "#8a5a0b", "margin": "10px 0 0"}}>
                Reporting channels are placeholder labels: snapshot, verify before use.
            </p>
        </div>

        <div style={CARD}>
            <h3 style={LABEL}>{"Ripoti (Kiswahili)" if lang == "sw" else "Report (English)"}</h3>
            {if isPending {
                <textarea
                    value={draftSw if lang == "sw" else draftEn}
                    onChange={lambda (e: ChangeEvent) {
                        if lang == "sw" { draftSw = e.target.value; } else { draftEn = e.target.value; }
                    }}
                    rows={12}
                    lang={lang}
                    style={{**TEXTAREA, "fontSize": "16px"}}
                />
            } else {
                <textarea
                    readOnly={True}
                    value={(view["final_text_sw"] if lang == "sw" else view["final_text_en"]) or "(discarded)"}
                    rows={14}
                    lang={lang}
                    style={TEXTAREA}
                />
            }}
        </div>

        {if isPending {
            <div style={{"display": "flex", "flexDirection": "column", "gap": "10px"}}>
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
                <button type="button" disabled={busy} onClick={lambda { approve(); }} style={{**BUTTON, **PRIMARY}}>
                    <Icon name="tick" color="#fbf6ec"/>
                    Approve report
                </button>
                <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "8px"}}>
                    <button type="button" disabled={busy} onClick={lambda { saveEdits(); }} style={{**BUTTON, **QUIET}}>
                        Save edits
                    </button>
                    <button type="button" disabled={busy} onClick={lambda { discard(); }} style={{**BUTTON, **QUIET, "color": "#b23a24"}}>
                        Discard
                    </button>
                </div>
            </div>
        } elif view["status"] == "approved" {
            <button type="button" onClick={lambda { copyText(); }} style={{**BUTTON, **PRIMARY}}>
                <Icon name="copy" color="#fbf6ec"/>
                Copy report
            </button>
        }}
        {if notice {
            <p role="status" style={{"color": "#22694a", "margin": "0", "fontWeight": "500"}}>{notice}</p>
        }}
        {if error {
            <p role="alert" style={{**ALERT, "margin": "0"}}>{error}</p>
        }}
    </section>;
}
