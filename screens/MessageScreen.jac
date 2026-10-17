"""Message detail: the masked message and its full Verdict. Polls every 3s
while Guard is still analysing it."""

import from react {
    useEffect,
    useRef
}
import from "@jac/runtime" {
    Link,
    useParams
}
import from ..components.Icon {
    Icon
}
import from ..components.theme {
    BACK,
    ALERT,
    MUTED
}
import from ..components.VerdictPanel {
    VerdictPanel
}
import from ..components.LostMoneyButton {
    LostMoneyButton
}
import from ..services.api {
    callWalker
}


def:pub BackToFeed() -> JsxElement {
    return <Link to="/" style={BACK}>
        <Icon name="back"/>
        Feed
    </Link>;
}


def:pub MessageScreen(lang: str) -> JsxElement {
    params = useParams();
    messageId = params["id"] or "";
    has message: dict[str, any] | None = None,
        error: str = "";
    # Latest status for the poller, outside render state so the interval
    # never works from a stale closure.
    statusRef: any = useRef("");

    async def loadMessage -> None {
        reply = await callWalker("GetMessage", {"message_id": messageId});
        if reply["error"] {
            error = str(reply["error"]);
            return;
        }
        reports = reply["reports"] as list[dict[str, any]];
        found = reports[0] if len(reports) > 0 else None;
        if not found or found["status"] == "not_found" {
            statusRef.current = "not_found";
            error = "Message not found.";
            return;
        }
        statusRef.current = found["status"];
        error = "";
        message = found;
    }

    useEffect(lambda {
        statusRef.current = "";
        loadMessage();
        interval = setInterval(lambda {
            if statusRef.current in ["", "analysing"] {
                loadMessage();
            }
        }, 3000);
        return lambda { clearInterval(interval); };
    }, [messageId]);

    if error {
        return <section>
            <BackToFeed/>
            <p role="alert" style={ALERT}>{error}</p>
        </section>;
    }
    if not message {
        return <section>
            <BackToFeed/>
            <p style={MUTED}>Loading…</p>
        </section>;
    }
    shown = message as dict[str, any];
    waiting = {
        "borderRadius": "26px",
        "padding": "20px",
        "backgroundColor": "#ece6d8",
        "display": "flex",
        "flexDirection": "column",
        "gap": "10px",
        "overflowWrap": "anywhere"
    };
    return <section style={{"display": "flex", "flexDirection": "column", "gap": "6px"}}>
        <BackToFeed/>
        {if shown["status"] == "analysing" or shown["status"] == "failed" {
            <div style={waiting}>
                <strong style={{"fontSize": "15px"}}>{shown["sender_display"]}</strong>
                <span style={{"fontStyle": "italic", "color": "#4a6260"}}>{shown["display"]}</span>
                <span style={{"color": "#4a6260", "fontSize": "14px"}}>
                    {"Guard is checking this message…" if shown["status"] == "analysing" else "The check could not finish. It will be retried."}
                </span>
            </div>
        } else {
            <VerdictPanel verdict={shown} lang={lang} quote={shown["display"]} sender={shown["sender_display"]}/>
        }}
        <LostMoneyButton messageId={str(messageId)}/>
        <p style={{"margin": "6px 0 0", "fontSize": "12px", "color": "#6f817d", "textAlign": "center"}}>
            Decision aid, not legal advice.
        </p>
    </section>;
}
