"""Pesa Shield - Client-side feed UI (T1 tracer).

Mobile-first at 360px. Polls the WebFeed walker every 4 seconds while the
page is visible. State words follow GLOSSARY.md (analysing shown as-is).
"""

import from "react" {
    useEffect
}

import from .components.MessageCard {
    MessageCard
}

import from endpoints { WebFeed }


def:pub app -> JsxElement {
    has messages: list[dict[str, str]] = [];

    async def loadFeed -> None;

    # Poll every 4s while mounted.
    can with entry {
        loadFeed();
    }
    useEffect(lambda {
        interval = setInterval(lambda { loadFeed(); }, 4000);
        return lambda { clearInterval(interval); };
    }, []);

    <div
        style={{
            "maxWidth": "360px",
            "margin": "0 auto",
            "padding": "0 0.75rem",
            "fontFamily": "system-ui, -apple-system, sans-serif",
            "color": "#1a1a2e",
            "boxSizing": "content-box"
        }}
    >
        <h1 style={{"fontSize": "1.15rem", "margin": "0.9rem 0 0.15rem"}}>Pesa Shield</h1>
        <p style={{"color": "#666", "fontSize": "0.85rem", "margin": "0 0 0.9rem"}}>
            Live feed - updates every ~4s
        </p>
        {if len(messages) == 0 {
            <p style={{"color": "#999", "fontSize": "0.9rem"}}>No messages yet.</p>
            skip;
        }}
        {for (idx, msg) in enumerate(messages) {
            <MessageCard
                key={msg["id"] if msg["id"] else str(idx)}
                display={msg["display"]}
                senderDisplay={msg["sender_display"]}
                status={msg["status"]}
            />
        }}
    </div>
}
