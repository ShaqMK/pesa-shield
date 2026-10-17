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
import from ..components.RiskBadge {
    RiskBadge
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
    return <Link
        to="/"
        style={{
            "display": "inline-flex",
            "alignItems": "center",
            "minHeight": "44px",
            "color": "#1a3fb0",
            "textDecoration": "none"
        }}
    >
        ← Feed
    </Link>;
}


def:pub MessageScreen(lang: str) -> JsxElement {
    params = useParams();
    messageId = params["id"] or "";
    has message: dict | None = None,
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
        reports = reply["reports"] as list[dict];
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
            <p role="alert" style={{"color": "#a61b1b"}}>{error}</p>
        </section>;
    }
    if not message {
        return <section>
            <BackToFeed/>
            <p style={{"color": "#888"}}>Loading…</p>
        </section>;
    }
    shown = message as dict;
    return <section>
        <BackToFeed/>
        <div style={{"display": "flex", "justifyContent": "space-between", "gap": "0.5rem", "alignItems": "center"}}>
            <strong>{shown["sender_display"]}</strong>
            <RiskBadge risk={shown["risk"]} status={shown["status"]}/>
        </div>
        <blockquote
            style={{
                "margin": "0.6rem 0 0.9rem",
                "padding": "0.7rem 0.8rem",
                "backgroundColor": "#f8f9fa",
                "borderLeft": "4px solid #ccd",
                "overflowWrap": "anywhere"
            }}
        >
            {shown["display"]}
        </blockquote>
        {if shown["status"] == "analysing" {
            <p style={{"color": "#666"}}>Guard is checking this message…</p>
        } elif shown["status"] == "failed" {
            <p style={{"color": "#666"}}>The check could not finish. It will be retried.</p>
        } else {
            <VerdictPanel verdict={shown} lang={lang}/>
        }}
        <LostMoneyButton messageId={str(messageId)}/>
    </section>;
}
